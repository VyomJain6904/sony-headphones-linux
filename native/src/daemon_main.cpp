#include "sony/backend.hpp"
#include "sony/command.hpp"
#include "sony/state.hpp"

#include <array>
#include <atomic>
#include <cerrno>
#include <csignal>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <memory>
#include <poll.h>
#include <string>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

namespace {

std::atomic_bool running{true};

void stopSignal(int) { running.store(false); }

class FileDescriptor {
 public:
  FileDescriptor() = default;
  explicit FileDescriptor(int value) : value_(value) {}
  ~FileDescriptor() { reset(); }
  FileDescriptor(const FileDescriptor&) = delete;
  FileDescriptor& operator=(const FileDescriptor&) = delete;
  FileDescriptor(FileDescriptor&& other) noexcept : value_(other.release()) {}
  FileDescriptor& operator=(FileDescriptor&& other) noexcept {
    if (this != &other) reset(other.release());
    return *this;
  }
  int get() const { return value_; }
  int release() { const int value = value_; value_ = -1; return value; }
  void reset(int value = -1) {
    if (value_ >= 0) ::close(value_);
    value_ = value;
  }
  explicit operator bool() const { return value_ >= 0; }

 private:
  int value_{-1};
};

bool socketIsLive(const std::filesystem::path& path) {
  FileDescriptor descriptor(::socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0));
  if (!descriptor) return false;
  sockaddr_un address{};
  address.sun_family = AF_UNIX;
  const std::string value = path.string();
  if (value.size() >= sizeof(address.sun_path)) return false;
  std::memcpy(address.sun_path, value.c_str(), value.size() + 1U);
  return ::connect(descriptor.get(), reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0;
}

FileDescriptor createServer(const std::filesystem::path& path, std::string& error) {
  std::string directoryError;
  if (!sony::ensurePrivateDirectory(path.parent_path(), directoryError)) {
    error = directoryError;
    return {};
  }
  if (path.string().size() >= sizeof(sockaddr_un::sun_path)) {
    error = "runtime socket path is too long";
    return {};
  }
  if (std::filesystem::exists(path)) {
    if (socketIsLive(path)) {
      error = "another sony-headphonesd is already running";
      return {};
    }
    std::error_code removeError;
    std::filesystem::remove(path, removeError);
    if (removeError) {
      error = "could not remove stale socket: " + removeError.message();
      return {};
    }
  }

  FileDescriptor descriptor(::socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0));
  if (!descriptor) {
    error = "could not create socket: " + std::string(std::strerror(errno));
    return {};
  }
  sockaddr_un address{};
  address.sun_family = AF_UNIX;
  const std::string value = path.string();
  std::memcpy(address.sun_path, value.c_str(), value.size() + 1U);
  if (::bind(descriptor.get(), reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0) {
    error = "could not bind socket: " + std::string(std::strerror(errno));
    return {};
  }
  if (::chmod(path.c_str(), S_IRUSR | S_IWUSR) != 0) {
    error = "could not secure socket: " + std::string(std::strerror(errno));
    return {};
  }
  if (::listen(descriptor.get(), 8) != 0) {
    error = "could not listen on socket: " + std::string(std::strerror(errno));
    return {};
  }
  return descriptor;
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

void handleClient(int client, sony::Backend& backend) {
  timeval timeout{1, 0};
  (void)::setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
  std::array<char, 4097> buffer{};
  const ssize_t received = ::recv(client, buffer.data(), 4096, 0);
  if (received <= 0) {
    (void)sendAll(client, "error empty request\n");
    return;
  }
  if (std::memchr(buffer.data(), '\0', static_cast<std::size_t>(received)) != nullptr) {
    (void)sendAll(client, "error NUL bytes are not accepted\n");
    return;
  }
  const std::string line(buffer.data(), static_cast<std::size_t>(received));
  const sony::ParseResult parsed = sony::parseCommandLine(line);
  if (!parsed.ok) {
    (void)sendAll(client, "error " + parsed.error + "\n");
    return;
  }
  if (parsed.command.kind == sony::CommandKind::Status) {
    (void)sendAll(client, "ok " + sony::serializeState(backend.state()));
    return;
  }
  const sony::ActionResult result = backend.handle(parsed.command);
  (void)sendAll(client, (result.ok ? "ok" : "error") + (result.message.empty() ? "" : " " + result.message) + "\n");
}

void printHelp() {
  std::cout
    << "sony-headphonesd " << SONY_HEADPHONES_VERSION << "\n"
    << "Usage: sony-headphonesd [--mock] [--idle-seconds N]\n"
    << "  --mock            expose deterministic WH-1000XM5 state without Bluetooth\n"
    << "  --idle-seconds N  release an unused control connection after N seconds (default 15)\n";
}

bool parseNonNegative(const char* value, int& result) {
  try {
    std::size_t consumed = 0;
    const int parsed = std::stoi(value, &consumed);
    if (value[consumed] != '\0' || parsed < 0 || parsed > 3600) return false;
    result = parsed;
    return true;
  } catch (...) {
    return false;
  }
}

}  // namespace

int main(int argc, char** argv) {
  bool mock = false;
  int idleSeconds = 15;
  for (int index = 1; index < argc; ++index) {
    const std::string argument = argv[index];
    if (argument == "--mock") mock = true;
    else if (argument == "--idle-seconds" && index + 1 < argc) {
      if (!parseNonNegative(argv[++index], idleSeconds)) {
        std::cerr << "--idle-seconds must be from 0 to 3600\n";
        return 2;
      }
    } else if (argument == "--help" || argument == "-h") {
      printHelp();
      return 0;
    } else if (argument == "--version") {
      std::cout << SONY_HEADPHONES_VERSION << '\n';
      return 0;
    } else {
      std::cerr << "unknown argument: " << argument << '\n';
      return 2;
    }
  }

  ::umask(S_IRWXG | S_IRWXO);
  std::signal(SIGINT, stopSignal);
  std::signal(SIGTERM, stopSignal);

  const std::filesystem::path statePath = sony::stateFilePath();
  const std::filesystem::path runtimeSocket = sony::socketPath();
  std::string error;
  FileDescriptor server = createServer(runtimeSocket, error);
  if (!server) {
    std::cerr << error << '\n';
    return 1;
  }

  std::unique_ptr<sony::Backend> backend = sony::createBackend(mock, idleSeconds);
  if (!sony::atomicWrite(statePath, sony::serializeState(backend->state()), error)) {
    std::cerr << error << '\n';
    return 1;
  }
  (void)backend->consumeDirty();

  std::cerr << "sony-headphonesd " << SONY_HEADPHONES_VERSION
            << (mock ? " (mock)" : "") << " listening at " << runtimeSocket << '\n';

  while (running.load()) {
    pollfd descriptor{server.get(), POLLIN, 0};
    const int pollResult = ::poll(&descriptor, 1, backend->pollTimeoutMs());
    if (pollResult < 0 && errno != EINTR) {
      std::cerr << "socket poll failed: " << std::strerror(errno) << '\n';
      break;
    }
    if (pollResult > 0 && (descriptor.revents & POLLIN) != 0) {
      while (true) {
        FileDescriptor client(::accept4(server.get(), nullptr, nullptr, SOCK_CLOEXEC));
        if (!client) {
          if (errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)
            std::cerr << "accept failed: " << std::strerror(errno) << '\n';
          break;
        }
        handleClient(client.get(), *backend);
      }
    }

    backend->tick();
    if (backend->consumeDirty()) {
      if (!sony::atomicWrite(statePath, sony::serializeState(backend->state()), error))
        std::cerr << error << '\n';
    }
  }

  server.reset();
  std::error_code ignored;
  std::filesystem::remove(runtimeSocket, ignored);
  std::filesystem::remove(statePath, ignored);
  return 0;
}
