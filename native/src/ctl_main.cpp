#include "sony/command.hpp"
#include "sony/state.hpp"

#include <array>
#include <cerrno>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <vector>

namespace {

class FileDescriptor {
 public:
  explicit FileDescriptor(int value = -1) : value_(value) {}
  ~FileDescriptor() { if (value_ >= 0) ::close(value_); }
  FileDescriptor(const FileDescriptor&) = delete;
  FileDescriptor& operator=(const FileDescriptor&) = delete;
  int get() const { return value_; }
  explicit operator bool() const { return value_ >= 0; }
 private:
  int value_;
};

std::string join(const std::vector<std::string>& words) {
  std::ostringstream out;
  for (std::size_t index = 0; index < words.size(); ++index) {
    if (index > 0) out << ' ';
    out << words[index];
  }
  out << '\n';
  return out.str();
}

bool sendAll(int descriptor, const std::string& data) {
  std::size_t offset = 0;
  while (offset < data.size()) {
    const ssize_t sent = ::send(descriptor, data.data() + offset, data.size() - offset, MSG_NOSIGNAL);
    if (sent < 0) {
      if (errno == EINTR) continue;
      return false;
    }
    offset += static_cast<std::size_t>(sent);
  }
  return true;
}

int printStatusFile() {
  std::ifstream input(sony::stateFilePath());
  if (!input) {
    std::cerr << "status file not found; is sony-headphonesd running?\n";
    return 1;
  }
  std::cout << input.rdbuf();
  return input.bad() ? 1 : 0;
}

}  // namespace

int main(int argc, char** argv) {
  if (argc == 2 && (std::string(argv[1]) == "--version" || std::string(argv[1]) == "-V")) {
    std::cout << SONY_HEADPHONES_VERSION << '\n';
    return 0;
  }
  if (argc < 2 || (argc == 2 && (std::string(argv[1]) == "--help" || std::string(argv[1]) == "-h"))) {
    std::cout << "sony-headphonesctl " << SONY_HEADPHONES_VERSION << "\n" << sony::commandUsage();
    return argc < 2 ? 2 : 0;
  }

  std::vector<std::string> words;
  words.reserve(static_cast<std::size_t>(argc - 1));
  for (int index = 1; index < argc; ++index) words.emplace_back(argv[index]);
  const sony::ParseResult parsed = sony::parseCommand(words);
  if (!parsed.ok) {
    std::cerr << parsed.error << '\n';
    return 2;
  }
  if (parsed.command.kind == sony::CommandKind::Status) return printStatusFile();

  const std::string path = sony::socketPath().string();
  if (path.size() >= sizeof(sockaddr_un::sun_path)) {
    std::cerr << "runtime socket path is too long\n";
    return 1;
  }
  FileDescriptor descriptor(::socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0));
  if (!descriptor) {
    std::cerr << "could not create socket: " << std::strerror(errno) << '\n';
    return 1;
  }
  sockaddr_un address{};
  address.sun_family = AF_UNIX;
  std::memcpy(address.sun_path, path.c_str(), path.size() + 1U);
  if (::connect(descriptor.get(), reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0) {
    std::cerr << "could not contact sony-headphonesd: " << std::strerror(errno) << '\n';
    return 1;
  }
  if (!sendAll(descriptor.get(), join(words))) {
    std::cerr << "could not send command: " << std::strerror(errno) << '\n';
    return 1;
  }
  (void)::shutdown(descriptor.get(), SHUT_WR);

  std::array<char, 8192> buffer{};
  const ssize_t received = ::recv(descriptor.get(), buffer.data(), buffer.size() - 1U, 0);
  if (received <= 0) {
    std::cerr << "daemon returned no response\n";
    return 1;
  }
  std::string response(buffer.data(), static_cast<std::size_t>(received));
  while (!response.empty() && (response.back() == '\n' || response.back() == '\r')) response.pop_back();
  if (response == "ok") return 0;
  if (response.rfind("ok ", 0) == 0) {
    std::cout << response.substr(3) << '\n';
    return 0;
  }
  if (response.rfind("error ", 0) == 0) {
    std::cerr << response.substr(6) << '\n';
    return 1;
  }
  std::cerr << "malformed daemon response\n";
  return 1;
}
