#include "hackatime_doctor.h"
#include "checks.h"

namespace fs = std::filesystem;

bool try_install_package(const std::string& package_name) {
    #ifdef _WIN32
        const std::string CHOCO_INSTALL_CMD = "@\"%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe\" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command \"[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))\" && SET \"PATH=%PATH%;%ALLUSERSPROFILE%\\chocolatey\\bin\"";
        
        if (system(("where choco > temp.txt")) != 0) {
            std::cout << "Chocolatey package manager is required but not found.\n";
            std::cout << "Would you like to install Chocolatey now? [Y/n]: ";
            std::string response;
            std::getline(std::cin, response);
            
            if (response.empty() || tolower(response[0]) == 'y') {
                std::cout << "Installing Chocolatey (Admin privileges required)...\n";
                int result = system(CHOCO_INSTALL_CMD.c_str());
                if (result != 0) {
                    std::cerr << "Failed to install Chocolatey.\n";
                    return false;
                }
            } else {
                std::cout << "Skipping Chocolatey installation.\n";
                return false;
            }
        }

        std::cout << "Attempting to install " << package_name << " using choco...\n";
        std::string cmd = "choco install -y " + package_name;
        if (system(cmd.c_str()) == 0) {
            return true;
        }
        return false;

    #elif __APPLE__
        const std::string BREW_INSTALL_CMD = "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"";
        
        if (system("which brew > temp.txt") != 0) {
            std::cout << "Homebrew package manager is required but not found.\n";
            std::cout << "Would you like to install Homebrew now? [Y/n]: ";
            std::string response;
            std::getline(std::cin, response);
            
            if (response.empty() || tolower(response[0]) == 'y') {
                std::cout << "Installing Homebrew...\n";
                int result = system(BREW_INSTALL_CMD.c_str());
                if (result != 0) {
                    std::cerr << "Failed to install Homebrew.\n";
                    return false;
                }
                
                system("eval \"$(/opt/homebrew/bin/brew shellenv)\"");
            } else {
                std::cout << "Skipping Homebrew installation.\n";
                return false;
            }
        }

        std::cout << "Attempting to install " << package_name << " using brew...\n";
        std::string cmd = "brew install " + package_name;
        if (system(cmd.c_str()) == 0) {
            return true;
        }
        return false;
    #endif

    std::vector<std::pair<std::string, std::string>> package_managers = {
        {"pacman", "sudo pacman -S --noconfirm " + package_name},
        {"apt", "sudo apt-get install -y " + package_name},
        {"dnf", "sudo dnf install -y " + package_name},
        {"aptitude", "sudo aptitude install -y " + package_name},
        {"yum", "sudo yum install -y " + package_name},
        {"zypper", "sudo zypper --non-interactive install " + package_name},
        {"apk", "sudo apk add " + package_name},
        {"emerge", "sudo emerge --ask n " + package_name},
        {"xbps-install", "sudo xbps-install -y " + package_name},
        {"eopkg", "sudo eopkg install -y " + package_name},
        {"nix-env", "nix-env -i " + package_name},
        {"slackpkg", "sudo slackpkg install " + package_name},
        {"swupd", "sudo swupd bundle-add " + package_name}
    };

    for (const auto& [manager, cmd] : package_managers) {
        if (system(("which " + manager + " > temp.txt").c_str()) == 0) {
            std::cout << "Attempting to install " << package_name 
                      << " using " << manager << "...\n";
            int result = system(cmd.c_str());
            if (result == 0) {
                return true;
            }
        }
    }
    return false;
}

CheckResult check_git_installed() {
    int result = system("git --version > temp.txt");
    if (result == 0) {
        return CheckResult{true, "Git is installed", "git_check"};
    }

    std::cout << COLOR_YELLOW 
              << "Git is not installed. Would you like to install it now? [Y/n] " 
              << COLOR_RESET;
    std::string response;
    std::getline(std::cin, response);
    
    if (!response.empty() && tolower(response[0]) == 'n') {
        return CheckResult{false, "Git is not installed (user declined installation)", "git_check"};
    }

    if (try_install_package("git")) {
        if (system("git --version > temp.txt") == 0) {
            return CheckResult{true, "Git was successfully installed", "git_check"};
        } else {
            #ifdef _WIN32
                 return CheckResult{true, 
                      "Git was probably installed successfully.\n"
                      "Please RESTART YOUR TERMINAL for Git to become available.\n"
                      "After restarting, run 'git --version' to verify.", 
                      "git_check"
                 };
            #endif
        }
    }

    return CheckResult{false, 
        "Failed to install Git. Please install it manually:\n"
        "  Windows: https://git-scm.com/download/win\n"
        "  Mac: brew install git\n"
        "  Linux: Use your package manager (apt, dnf, pacman, etc.)",
        "git_check"};
}

CheckResult check_node_installed() {
    int result = system("node --version > temp.txt");
    if (result != 0) {
        std::cout << COLOR_YELLOW 
                  << "Node.js is not installed. Would you like to install it now? [Y/n] " 
                  << COLOR_RESET;
        std::string response;
        std::getline(std::cin, response);
        
        if (!response.empty() && tolower(response[0]) == 'n') {
            return CheckResult{false, "Node.js is not installed (user declined installation)", "nodejs_check"};
        }

        if (try_install_package("nodejs") || try_install_package("node")) {
            if (system("node --version > temp.txt") == 0) {
                #ifdef _WIN32
                    return CheckResult{true, 
                        "Node.js was probably installed successfully.\n"
                        "Please RESTART YOUR TERMINAL for Node.js to become available.\n"
                        "After restarting, run 'node --version' to verify.", 
                        "nodejs_check"
                    };
                #else 
                    return check_node_installed(); 
                #endif
            }
        }

        return CheckResult{false,
            "Failed to install Node.js. Please install it manually:\n"
            "  Windows: https://nodejs.org/en/download/\n"
            "  Mac: brew install node\n"
            "  Linux: Use your package manager (apt, dnf, pacman, etc.)\n"
            "  Recommended: Use nvm (https://github.com/nvm-sh/nvm)",
            "nodejs_check"};
    }

    FILE* pipe = popen("node --version", "r");
    if (!pipe) return CheckResult{true, "Node.js is installed (version check failed)", "nodejs_check"};
    
    char buffer[128];
    std::string version;
    while (!feof(pipe)) {
        if (fgets(buffer, 128, pipe) != NULL)
            version += buffer;
    }
    pclose(pipe);
    
    int major_version = 0;
    if (sscanf(version.c_str(), "v%d", &major_version) == 1) {
        if (major_version >= 16) {
            return CheckResult{true, "Node.js v" + std::to_string(major_version) + " is installed", "nodejs_check"};
        }
        
        std::cout << COLOR_YELLOW 
                  << "Node.js version is too old (v" << major_version << "). Would you like to update? [Y/n] "
                  << COLOR_RESET;
        std::string response;
        std::getline(std::cin, response);
        
        if (!response.empty() && tolower(response[0]) == 'n') {
            return CheckResult{false, "Node.js version too old (v" + std::to_string(major_version) + "), need v16+", "nodejs_check"};
        }

        if (try_install_package("nodejs") || try_install_package("node")) {
            return check_node_installed(); 
        }

        return CheckResult{false,
            "Failed to update Node.js. Please update manually:\n"
            "  Recommended: Use nvm (https://github.com/nvm-sh/nvm)\n"
            "  Or use your system package manager",
            "nodejs_check"};
    }
    
    return CheckResult{true, "Node.js is installed (version check inconclusive)", "nodejs_check"};
}

CheckResult check_folder_structure() {
    const std::vector<std::string> required_files = {
        "README.md",
        "LICENSE",
        ".gitignore"
    };

    bool all_exist = true;
    for (const auto& file : required_files) {
        if (!fs::exists(file) || !fs::is_regular_file(file)) {
            all_exist = false;
            break;
        }
    }

    if (all_exist) {
        return CheckResult{true, "All required files present", "folder_structure_check"};
    }

    std::string missing;
    for (const auto& file : required_files) {
        if (!fs::exists(file)) {
            if (!missing.empty()) missing += ", ";
            missing += file;
        }
    }

    return CheckResult{false, "Missing required files: " + missing, "folder_structure_check"};
}

CheckResult check_api_tokens() {
    const char* api_key = std::getenv("HACKATIME_API_KEY");
    const char* api_url = std::getenv("HACKATIME_API_URL");
    
    if (!api_key || !api_url) {
        std::string error = "Missing environment variables:";
        if (!api_key) error += "\n  - HACKATIME_API_KEY";
        if (!api_url) error += "\n  - HACKATIME_API_URL";
        error += "\nGet them from: https://hackatime.hackclub.com/my/wakatime_setup";
        return CheckResult{false, error, "api_connection_check"};
    }

    std::string full_url = std::string(api_url) + "/users/current/heartbeats";
    
    size_t protocol_end = full_url.find("://");
    if (protocol_end == std::string::npos) {
        return CheckResult{false, "Invalid API URL format (missing protocol)", "api_connection_check"};
    }

    size_t host_start = protocol_end + 3;
    size_t path_start = full_url.find('/', host_start);
    
    std::string host = full_url.substr(host_start, path_start - host_start);
    std::string path = path_start != std::string::npos ? full_url.substr(path_start) : "/";
    
    int port = full_url.find("https://") == 0 ? 443 : 80;

    SSL_CTX* ctx = nullptr;
    SSL* ssl = nullptr;
    if (port == 443) {
        SSL_library_init();
        SSL_load_error_strings();
        OpenSSL_add_all_algorithms();
        ctx = SSL_CTX_new(TLS_client_method());
        if (!ctx) {
            return CheckResult{false, "SSL context creation failed", "api_connection_check"};
        }
    }

    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        if (ctx) SSL_CTX_free(ctx);
        return CheckResult{false, "Socket creation failed", "api_connection_check"};
    }

    hostent* server = gethostbyname(host.c_str());
    if (!server) {
        close_socket(sock);
        if (ctx) SSL_CTX_free(ctx);
        return CheckResult{false, "Host resolution failed", "api_connection_check"};
    }

    sockaddr_in serv_addr{};
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    memcpy(&serv_addr.sin_addr.s_addr, server->h_addr, server->h_length);

    if (connect(sock, (sockaddr*)&serv_addr, sizeof(serv_addr)) < 0) {
        close_socket(sock);
        if (ctx) SSL_CTX_free(ctx);
        return CheckResult{false, "Connection failed", "api_connection_check"};
    }

    if (port == 443) {
        ssl = SSL_new(ctx);
        SSL_set_fd(ssl, sock);
        if (SSL_connect(ssl) != 1) {
            SSL_free(ssl);
            close_socket(sock);
            SSL_CTX_free(ctx);
            return CheckResult{false, "SSL handshake failed" , "api_connection_check"};
        }
    }

    std::time_t now = std::time(nullptr);
    std::string payload = R"([{
        "type": "file",
        "time": )" + std::to_string(now) + R"(,
        "entity": "hackatime-doctor-validate.txt",
        "language": "Text"
    }])";

    std::string request = "POST " + path + " HTTP/1.1\r\n"
                       "Host: " + host + "\r\n"
                       "Authorization: Bearer " + std::string(api_key) + "\r\n"
                       "Content-Type: application/json\r\n"
                       "Content-Length: " + std::to_string(payload.length()) + "\r\n\r\n"
                       + payload;

    int bytes_sent;
    if (port == 443) {
        bytes_sent = SSL_write(ssl, request.c_str(), request.length());
    } else {
        bytes_sent = send(sock, request.c_str(), request.length(), 0);
    }

    if (bytes_sent <= 0) {
        if (ssl) SSL_free(ssl);
        close_socket(sock);
        if (ctx) SSL_CTX_free(ctx);
        return CheckResult{false, "Failed to send heartbeat", "api_connection_check"};
    }

    char buffer[4096];
    int bytes_received;
    if (port == 443) {
        bytes_received = SSL_read(ssl, buffer, sizeof(buffer)-1);
    } else {
        bytes_received = recv(sock, buffer, sizeof(buffer)-1, 0);
    }
    
    if (bytes_received <= 0) {
        if (ssl) SSL_free(ssl);
        close_socket(sock);
        if (ctx) SSL_CTX_free(ctx);
        return CheckResult{false, "No response from server", "api_connection_check"};
    }
    buffer[bytes_received] = '\0';

    if (ssl) {
        SSL_shutdown(ssl);
        SSL_free(ssl);
    }
    close_socket(sock);
    if (ctx) SSL_CTX_free(ctx);

    std::string response(buffer);
    if (response.find("HTTP/1.1 20") != std::string::npos) {  
        return CheckResult{true, "Heartbeat sent successfully, hackatime is working!", "api_connection_check"};
    }
    
    return CheckResult{false, "API request failed: " + response.substr(0, response.find("\r\n\r\n")), "api_connection_check"};
}

#ifdef _WIN32
std::string expandWindowsPath(const std::string& path_template) {
    std::string result = path_template;
    
    if (result.front() == '~') {
        char homeDir[MAX_PATH];
        if (SUCCEEDED(SHGetFolderPathA(NULL, CSIDL_PROFILE, NULL, 0, homeDir))) {
            result = std::string(homeDir) + result.substr(1);
        }
    }
    
    size_t start = 0;
    while ((start = result.find('%', start)) != std::string::npos) {
        size_t end = result.find('%', start + 1);
        if (end != std::string::npos) {
            std::string varName = result.substr(start + 1, end - start - 1);
            char varValue[MAX_PATH];
            DWORD varLen = GetEnvironmentVariableA(varName.c_str(), varValue, MAX_PATH);
            if (varLen > 0 && varLen < MAX_PATH) {
                result.replace(start, end - start + 1, varValue);
                start += varLen;
            } else {
                start = end + 1;
            }
        } else {
            break;
        }
    }
    
    return result;
}
#else
std::string expandPosixPath(const std::string& path_template) {
    wordexp_t expanded;
    if (wordexp(path_template.c_str(), &expanded, WRDE_NOCMD) == 0) {
        if (expanded.we_wordc > 0) {
            std::string result = expanded.we_wordv[0];
            wordfree(&expanded);
            return result;
        }
        wordfree(&expanded);
    }
    return path_template; 
}
#endif

CheckResult check_wakatime_config() {
    std::vector<std::string> search_paths = {
        "${WAKATIME_HOME}/.wakatime.cfg",
        "${XDG_CONFIG_HOME:-$HOME/.config}/wakatime/.wakatime.cfg",
        "$HOME/.wakatime.cfg",
        "/etc/wakatime.cfg",
        "/usr/local/etc/wakatime.cfg"
    };

    std::string config_path;
    std::string config_content;

    for (const auto& path_template : search_paths) {
        #ifdef _WIN32
            std::string path = expandWindowsPath(path_template);
        #else
            std::string path = expandPosixPath(path_template);
        #endif
    
        std::ifstream file(path);
        if (file.is_open()) {
            config_path = path;
            config_content.assign((std::istreambuf_iterator<char>(file)), 
                             std::istreambuf_iterator<char>());
            file.close();
            if (config_content.find("[settings]") != std::string::npos) {
                break;
            }
        }
    }


    if (config_path.empty()) {
        std::cout << "No WakaTime config found. Would you like to create one? [Y/n] ";
        std::string response;
        std::getline(std::cin, response);
        
        if (!response.empty() && tolower(response[0]) == 'n') {
            return CheckResult{false, 
                "WakaTime config not found and user declined to create one",
                "wakatime_config"};
        }

        const char* home = std::getenv("HOME");
        if (!home) home = std::getenv("USERPROFILE");
        if (!home) {
            return CheckResult{false,
                "Could not determine home directory for config creation",
                "wakatime_config"};
        }

        config_path = std::string(home) + "/.wakatime.cfg";
        
        const char* api_url = std::getenv("HACKATIME_API_URL");
        const char* api_key = std::getenv("HACKATIME_API_KEY");
        
        if (!api_url || !api_key) {
            return CheckResult{false,
                "Missing HACKATIME_API_URL or HACKATIME_API_KEY environment variables",
                "wakatime_config"};
        }

        std::ofstream config_file(config_path);
        if (!config_file) {
            return CheckResult{false,
                "Failed to create config file at " + config_path,
                "wakatime_config"};
        }

        config_file << "[settings]\n"
                   << "api_url = " << api_url << "\n"
                   << "api_key = " << api_key << "\n"
                   << "heartbeat_rate_limit_seconds = 30\n";
        
        std::cout << "Created WakaTime config at " << config_path << "\n";
        return CheckResult{true,
            "Successfully created WakaTime config",
            "wakatime_config"};
    }

    bool has_url = false;
    bool has_key = false;
    std::vector<std::string> issues;
    std::string current_section;

    std::istringstream content_stream(config_content);
    std::string line;
    int line_num = 0;

    while (std::getline(content_stream, line)) {
        line_num++;
        std::string trimmed = line;
        trimmed.erase(trimmed.begin(), 
                     std::find_if(trimmed.begin(), trimmed.end(),
                     [](int ch) { return !std::isspace(ch); }));

        if (trimmed.empty()) continue;

        if (trimmed[0] == '[' && trimmed.back() == ']') {
            current_section = trimmed.substr(1, trimmed.length() - 2);
            continue;
        }

        if (current_section != "settings") continue;

        size_t eq_pos = trimmed.find('=');
        if (eq_pos == std::string::npos) continue;

        std::string key = trimmed.substr(0, eq_pos);
        key.erase(std::find_if(key.rbegin(), key.rend(),
                 [](int ch) { return !std::isspace(ch); }).base(), key.end());

        std::string value = trimmed.substr(eq_pos + 1);
        value.erase(value.begin(),
                  std::find_if(value.begin(), value.end(),
                  [](int ch) { return !std::isspace(ch); }));

        if (key == "api_url") {
            has_url = true;
            if (value != "https://hackatime.hackclub.com/api/hackatime/v1") {
                issues.push_back("Incorrect API URL: " + value);
            }
        } else if (key == "api_key") {
            has_key = true;
            if (value.empty()) {
                issues.push_back("Empty API key");
            }
        }
    }

    if (!has_url) issues.push_back("Missing API URL");
    if (!has_key) issues.push_back("Missing API key");

    if (issues.empty()) {
        return CheckResult{true,
                         "Valid WakaTime config at " + config_path,
                         "wakatime_config"};
    } else {
        std::string message = "Issues in " + config_path + ":\n";
        for (const auto& issue : issues) {
            message += "  • " + issue + "\n";
        }
        message += "Please update your config or set environment variables";
        return CheckResult{false, message, "wakatime_config"};
    }
}
