#include "sx_ffmpeg_movie_writer.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cerrno>
#include <cstring>
#include <string>
#include <vector>

#if !defined(_WIN32)
#include <fcntl.h>
#include <signal.h>
#include <sys/wait.h>
#endif

using namespace godot;

namespace sx_godot {

SxFfmpegMovieWriter::~SxFfmpegMovieWriter() {
	_close_pipe();
}

uint32_t SxFfmpegMovieWriter::_get_audio_mix_rate() const {
	return 48000;
}

AudioServer::SpeakerMode SxFfmpegMovieWriter::_get_audio_speaker_mode() const {
	return AudioServer::SPEAKER_MODE_STEREO;
}

bool SxFfmpegMovieWriter::_handles_file(const String &p_path) const {
	return p_path.get_extension().to_lower() == String("sxpipe");
}

PackedStringArray SxFfmpegMovieWriter::_get_supported_extensions() const {
	PackedStringArray exts;
	exts.push_back("sxpipe");
	return exts;
}

String SxFfmpegMovieWriter::_webm_path_from_pipe(const String &p_base_path) const {
	String path = p_base_path;
	if (path.get_extension().to_lower() == String("sxpipe")) {
		return path.get_basename() + ".webm";
	}
	return path + ".webm";
}

bool SxFfmpegMovieWriter::_spawn_ffmpeg() {
#if defined(_WIN32)
	ERR_PRINT("SxFfmpegMovieWriter: raw ffmpeg pipe is not implemented on Windows yet");
	return false;
#else
	int fds[2];
	if (pipe(fds) != 0) {
		ERR_PRINT(vformat("SxFfmpegMovieWriter: pipe() failed: %s", strerror(errno)));
		return false;
	}

	const CharString webm_utf8 = webm_path_.utf8();
	const std::string size_arg =
			std::to_string(size_.width) + "x" + std::to_string(size_.height);
	const std::string fps_arg = std::to_string(fps_);

	pid_t pid = fork();
	if (pid < 0) {
		ERR_PRINT(vformat("SxFfmpegMovieWriter: fork() failed: %s", strerror(errno)));
		close(fds[0]);
		close(fds[1]);
		return false;
	}
	if (pid == 0) {
		// Child: ffmpeg reads raw RGB24 on stdin.
		dup2(fds[0], STDIN_FILENO);
		close(fds[0]);
		close(fds[1]);
		// Avoid inheriting Godot's noise on stderr beyond ffmpeg's own loglevel.
		execlp("ffmpeg",
				"ffmpeg",
				"-y",
				"-loglevel", "error",
				"-f", "rawvideo",
				"-pix_fmt", "rgb24",
				"-s", size_arg.c_str(),
				"-r", fps_arg.c_str(),
				"-i", "-",
				"-an",
				"-c:v", "libvpx-vp9",
				"-crf", "34",
				"-b:v", "0",
				"-row-mt", "1",
				"-cpu-used", "8",
				"-deadline", "realtime",
				"-pix_fmt", "yuv420p",
				webm_utf8.get_data(),
				(char *)nullptr);
		// execlp failed
		_exit(127);
	}

	close(fds[0]);
	// Large buffer helps when VP9 lags behind the film.
	int flags = fcntl(fds[1], F_GETFL, 0);
	(void)flags;
	write_fd_ = fds[1];
	ffmpeg_pid_ = pid;
	return true;
#endif
}

void SxFfmpegMovieWriter::_close_pipe() {
#if !defined(_WIN32)
	if (write_fd_ >= 0) {
		::close(write_fd_);
		write_fd_ = -1;
	}
	if (ffmpeg_pid_ > 0) {
		int status = 0;
		while (waitpid(ffmpeg_pid_, &status, 0) < 0 && errno == EINTR) {
		}
		if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
			if (!failed_) {
				ERR_PRINT(vformat("SxFfmpegMovieWriter: ffmpeg exited with status %d", status));
			}
			failed_ = true;
		}
		ffmpeg_pid_ = -1;
	}
#endif
}

bool SxFfmpegMovieWriter::_write_all(const uint8_t *data, size_t len) {
#if defined(_WIN32)
	(void)data;
	(void)len;
	return false;
#else
	size_t off = 0;
	while (off < len) {
		ssize_t n = ::write(write_fd_, data + off, len - off);
		if (n < 0) {
			if (errno == EINTR) {
				continue;
			}
			ERR_PRINT(vformat("SxFfmpegMovieWriter: write failed: %s", strerror(errno)));
			return false;
		}
		off += static_cast<size_t>(n);
	}
	return true;
#endif
}

Error SxFfmpegMovieWriter::_write_begin(const Vector2i &p_movie_size, uint32_t p_fps,
		const String &p_base_path) {
	_close_pipe();
	failed_ = false;
	frames_ = 0;
	skipped_gate_ = 0;
	skipped_dup_ = 0;
	last_rgb_.clear();
	size_ = p_movie_size;
	fps_ = p_fps == 0 ? 30 : p_fps;
	webm_path_ = _webm_path_from_pipe(p_base_path);

	UtilityFunctions::print(vformat(
			"SxFfmpegMovieWriter: raw RGB24 → ffmpeg VP9 (%dx%d @ %dfps) → %s",
			size_.width, size_.height, (int)fps_, webm_path_));
	UtilityFunctions::print(
			"SxFfmpegMovieWriter: waiting for SX_MOVIE_RECORD=1 (set by film runner)");

	if (!_spawn_ffmpeg()) {
		failed_ = true;
		return ERR_CANT_CREATE;
	}
	return OK;
}

Error SxFfmpegMovieWriter::_write_frame(const Ref<Image> &p_frame_image,
		const void *p_audio_frame_block) {
	(void)p_audio_frame_block; // UI demos are silent; ffmpeg runs with -an.
	if (failed_ || p_frame_image.is_null()) {
		return ERR_UNCONFIGURED;
	}

	// Film runner arms this only around run_film() so boot/teardown aren't encoded.
	if (OS::get_singleton()->get_environment("SX_MOVIE_RECORD") != String("1")) {
		skipped_gate_++;
		return OK;
	}

	Ref<Image> img;
	img.instantiate();
	img->copy_from(p_frame_image);
	if (img->get_format() != Image::FORMAT_RGB8) {
		img->convert(Image::FORMAT_RGB8);
	}
	if (img->get_width() != size_.width || img->get_height() != size_.height) {
		img->resize(size_.width, size_.height, Image::INTERPOLATE_BILINEAR);
		if (img->get_format() != Image::FORMAT_RGB8) {
			img->convert(Image::FORMAT_RGB8);
		}
	}

	const PackedByteArray bytes = img->get_data();
	const size_t expect = static_cast<size_t>(size_.width) * static_cast<size_t>(size_.height) * 3u;
	if (static_cast<size_t>(bytes.size()) != expect) {
		ERR_PRINT(vformat("SxFfmpegMovieWriter: unexpected frame bytes %d (want %d)",
				(int64_t)bytes.size(), (int64_t)expect));
		failed_ = true;
		return ERR_INVALID_DATA;
	}

	// Drop exact duplicate presents (can happen if the loop ticks without a new draw).
	if (last_rgb_.size() == bytes.size() && last_rgb_ == bytes) {
		skipped_dup_++;
		return OK;
	}
	last_rgb_ = bytes;

	if (!_write_all(bytes.ptr(), expect)) {
		failed_ = true;
		return ERR_FILE_CANT_WRITE;
	}
	frames_++;
	return OK;
}

void SxFfmpegMovieWriter::_write_end() {
	_close_pipe();
	UtilityFunctions::print(vformat(
			"SxFfmpegMovieWriter: finished %d frames → %s%s (skipped gate=%d dup=%d)",
			(int64_t)frames_, webm_path_, failed_ ? " (FAILED)" : "",
			(int64_t)skipped_gate_, (int64_t)skipped_dup_));
}

} // namespace sx_godot
