#pragma once
// MovieWriter that pipes raw RGB24 frames to ffmpeg stdin (no AVI/MJPEG on disk).
// Handles --write-movie paths ending in .sxpipe → writes sibling .webm via libvpx-vp9.

#include <godot_cpp/classes/movie_writer.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

#include <cstdint>

#if !defined(_WIN32)
#include <sys/types.h>
#include <unistd.h>
#endif

namespace sx_godot {

class SxFfmpegMovieWriter : public godot::MovieWriter {
	GDCLASS(SxFfmpegMovieWriter, godot::MovieWriter)

public:
	SxFfmpegMovieWriter() = default;
	~SxFfmpegMovieWriter() override;

	uint32_t _get_audio_mix_rate() const override;
	godot::AudioServer::SpeakerMode _get_audio_speaker_mode() const override;
	bool _handles_file(const godot::String &p_path) const override;
	godot::PackedStringArray _get_supported_extensions() const override;
	godot::Error _write_begin(const godot::Vector2i &p_movie_size, uint32_t p_fps,
			const godot::String &p_base_path) override;
	godot::Error _write_frame(const godot::Ref<godot::Image> &p_frame_image,
			const void *p_audio_frame_block) override;
	void _write_end() override;

protected:
	static void _bind_methods() {}

private:
	godot::Vector2i size_;
	uint32_t fps_ = 30;
	godot::String webm_path_;
	uint64_t frames_ = 0;
	uint64_t skipped_gate_ = 0;
	uint64_t skipped_dup_ = 0;
	bool failed_ = false;
	godot::PackedByteArray last_rgb_;

#if !defined(_WIN32)
	int write_fd_ = -1;
	pid_t ffmpeg_pid_ = -1;
#endif

	godot::String _webm_path_from_pipe(const godot::String &p_base_path) const;
	bool _spawn_ffmpeg();
	void _close_pipe();
	bool _write_all(const uint8_t *data, size_t len);
};

} // namespace sx_godot
