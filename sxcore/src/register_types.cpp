#include <gdextension_interface.h>
#include <godot_cpp/classes/movie_writer.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "sx_document.hpp"
#include "sx_ffmpeg_movie_writer.hpp"
#include "sx_interop.hpp"
#include "sx_measure.hpp"
#include "sx_sketch.hpp"
#include "sx_voice.hpp"
#include "sx_voice_stt.hpp"

using namespace godot;

static sx_godot::SxFfmpegMovieWriter *s_ffmpeg_movie_writer = nullptr;

static void initialize_sxcore(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	ClassDB::register_class<sx_godot::SxDocument>();
	ClassDB::register_class<sx_godot::SxMeasure>();
	ClassDB::register_class<sx_godot::SxInterop>();
	ClassDB::register_class<sx_godot::SxSketch>();
	ClassDB::register_class<sx_godot::SxVoice>();
	ClassDB::register_class<sx_godot::SxVoiceStt>();
	ClassDB::register_class<sx_godot::SxFfmpegMovieWriter>();

	// Must register before Main finds a writer for --write-movie (SCENE init).
	s_ffmpeg_movie_writer = memnew(sx_godot::SxFfmpegMovieWriter);
	MovieWriter::add_writer(s_ffmpeg_movie_writer);
}

static void uninitialize_sxcore(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	if (s_ffmpeg_movie_writer) {
		memdelete(s_ffmpeg_movie_writer);
		s_ffmpeg_movie_writer = nullptr;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT sxcore_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_sxcore);
	init_obj.register_terminator(uninitialize_sxcore);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
