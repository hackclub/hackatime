#ifndef CHECKS_H
#define CHECKS_H

#include <cstdlib>    
#include <cstdio>     
#include <cstring>    
#include <string>     
#include <vector>     
#include <ctime>      
#include <fstream>    
#include <regex>      
#include <sstream>
#include <iostream>

#if __has_include(<filesystem>)
  #include <filesystem>
  namespace fs = std::filesystem;
#elif __has_include(<experimental/filesystem>)
  #include <experimental/filesystem>
  namespace fs = std::experimental::filesystem;
#else
  #error "No filesystem support!"
#endif

#if defined(_WIN32)
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #include <windows.h>
    #include <shlobj.h>
    #pragma comment(lib, "ws2_32.lib")
    #pragma comment(lib, "crypt32.lib")
    #define close_socket closesocket
    using socket_t = SOCKET;
#else
    #include <wordexp.h>
    #include <sys/socket.h>
    #include <netdb.h>
    #include <unistd.h>
    #include <arpa/inet.h>
    #define close_socket close
    using socket_t = int;
    #define INVALID_SOCKET -1
#endif

#include <openssl/ssl.h>
#include <openssl/err.h>

#endif
