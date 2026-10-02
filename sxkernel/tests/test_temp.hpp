#pragma once

// Portable temp paths for Catch tests. Hardcoded "/tmp/..." fails on native
// Windows (MSVC CreateFile); use the OS temp directory instead.

#include <cstdio>
#include <filesystem>
#include <string>

namespace sx::test {

inline std::string temp_path(const std::string& filename) {
    return (std::filesystem::temp_directory_path() / filename).string();
}

struct TmpFile {
    std::string path;
    explicit TmpFile(const std::string& filename) : path(temp_path(filename)) {}
    ~TmpFile() { std::remove(path.c_str()); }
};

}  // namespace sx::test
