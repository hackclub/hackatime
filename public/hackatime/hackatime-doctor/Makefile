CXX := g++
MKDIR := mkdir -p
RM := rm -rf

SRC_DIR := src
INCLUDE_DIR := include
OBJ_DIR := obj
BUILD_DIR := bin
TEST_DIR := tests

SRCS := $(wildcard $(SRC_DIR)/*.cpp)
MAIN_SRC := $(SRC_DIR)/main.cpp
CHECK_SRCS := $(filter-out $(MAIN_SRC), $(SRCS))
OBJS := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(SRCS))
MAIN_OBJ := $(OBJ_DIR)/main.o
CHECK_OBJS := $(filter-out $(MAIN_OBJ), $(OBJS))
DEPS := $(OBJS:.o=.d)

TARGET := $(BUILD_DIR)/hackatime-doctor
TEST_TARGET := $(BUILD_DIR)/hackatime-tests

CXXFLAGS := -std=c++17 -Wall -Wextra -pedantic -I$(INCLUDE_DIR)
DEBUG_FLAGS := -g -O0
RELEASE_FLAGS := -O3 -DNDEBUG

LDFLAGS := -lssl -lcrypto
TEST_LDFLAGS := -lgtest -lgtest_main -lpthread

BUILD_TYPE ?= debug
ifeq ($(BUILD_TYPE),release)
    CXXFLAGS += $(RELEASE_FLAGS)
else
    CXXFLAGS += $(DEBUG_FLAGS)
endif

all: $(TARGET)

$(TARGET): $(OBJS)
	@$(MKDIR) $(@D)
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS)

test: $(TEST_TARGET)
	@$(TEST_TARGET)

$(TEST_TARGET): $(CHECK_OBJS) $(TEST_DIR)/tests.cpp
	@$(MKDIR) $(@D)
	$(CXX) $(CXXFLAGS) $^ -o $@ $(LDFLAGS) $(TEST_LDFLAGS)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@$(MKDIR) $(@D)
	$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

-include $(DEPS)

release: BUILD_TYPE=release
release: clean all

install:
	@echo "To install, copy $(TARGET) to a directory in your PATH"
	@echo "Example: sudo cp $(TARGET) /usr/local/bin/"

uninstall:
	@echo "To uninstall, remove the binary from your PATH"
	@echo "Example: sudo rm /usr/local/bin/hackatime-doctor"

format:
	find $(SRC_DIR) $(INCLUDE_DIR) -name '*.cpp' -o -name '*.h' | xargs clang-format -i

clean:
	$(RM) $(OBJ_DIR) $(BUILD_DIR)

help:
	@echo "Available targets:"
	@echo "  all      - Build the application (debug mode)"
	@echo "  release  - Build optimized release version"
	@echo "  test     - Build and run tests"
	@echo "  clean    - Clean build files"
	@echo "  format   - Format source code with clang-format"
	@echo "  install  - Show install instructions"
	@echo "  uninstall- Show uninstall instructions"
	@echo "  help     - Show this help"

.PHONY: all test clean install uninstall format release help
