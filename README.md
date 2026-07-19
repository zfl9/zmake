# ZMake

ZMake 是 Zig 构建系统的一个适配层工具，它可以将现有 C/C++ 构建系统无缝融入 Zig 生态。

## 背景

C/C++ 开发者长期缺乏集**包管理**与**构建**于一体的现代工具链。Autotools 与 CMake 仅聚焦于构建本身，并无内置的包管理能力；包管理长期依赖于手动下载、git submodule 或系统包管理器，体验割裂。

Zig 提供了完整的解决方案：

- **`build.zig.zon`** — 去中心化的包管理器。任何 tarball（`.tar.gz`、`.zip` 等）均可作为 Zig 包纳入依赖管理，tarball 内无需包含 Zig 构建元数据。
- **`zig build`** — 内置构建系统，用强类型 & 通用的 Zig 编程语言（而非 Autotools/CMake 等领域特定语言）来描述构建过程，与包管理器深度集成。
- **`zig cc` / `zig c++`** — 基于 Clang/LLVM 的全功能编译工具链。内置各目标平台的 libc/libc++ 源码，提供一流的、开箱即用的交叉编译支持。

```bash
# 引入 C 库依赖，自动写入 build.zig.zon
zig fetch --save=wolfssl https://github.com/wolfSSL/wolfssl/archive/refs/tags/v5.9.2-stable.tar.gz

# 一键编译
zig build

# 一键交叉编译
zig build -Dtarget=aarch64-linux-musl
zig build -Dtarget=x86_64-linux-musl -Dcpu=x86_64_v3
```

包管理、构建系统、编译 & 交叉编译，三者合一，这正是 C/C++ 生态长久以来缺失的关键拼图。

## 问题

若上游 C/C++ 项目已原生支持 `build.zig` 且被积极维护，这无疑是最理想的情况（此时亦不需要 ZMake）。然而，绝大多数现有 C/C++ 库并不原生支持 `build.zig`。

面对这些库，社区的常见做法是由第三方为它们编写一份 `build.zig`。但复杂 C/C++ 项目的构建系统并非小工程——老牌库的构建脚本通常积累了数十年的环境探测、平台特定标志与条件编译逻辑，要将其完整、准确地复刻到 `build.zig` 中极其困难。这导致此类第三方的 `build.zig` 往往存在特性缺失，或停留在玩具级别，难以用于生产。此外，一旦上游源码重构或新增文件，这份 `build.zig` 就会迅速失效，引入高昂的二次维护成本。

## 解法

ZMake 的核心思想是**驱动而非重写**。你无需修改上游的任何构建脚本，只需在你的 `build.zig.zon` 中将 C/C++ 源码（tarball、git 仓库等）作为标准 Zig 包引入，然后在你的 `build.zig` 中调用 ZMake。ZMake 会在 Zig 的隔离沙盒中驱动上游原生的构建系统，同时将 Zig 的完整工具链与交叉编译能力透明注入其中。

> `build.zig.zon` 中的依赖包只需是一个标准 tarball（`.tar.gz`、`.zip` 等常见打包格式均可），**并不要求** tarball 内包含 `build.zig`、`build.zig.zon` 等 Zig 构建元数据。这正是 Zig 可以无缝承接 C/C++ 项目的基础能力。

### 核心特性

- **非侵入式 & 无需额外维护**：不修改上游源码，无需向上游项目引入或维护 `build.zig`。
- **工具链自动注入**：自动将 `zig cc` / `zig c++` 以及 Target、Optimize、LTO 等信息注入至上游构建系统。
- **缓存系统集成**：将所有的构建上下文序列化为一个描述文件，与 Zig 缓存系统优雅集成，确保并发构建的正确性。

## 快速开始

以 wolfssl 为例，将其原生 tarball 接入 Zig 构建系统。

> 这里仅作演示用途，[wolfssl-zig](https://github.com/zfl9/wolfssl-zig) 在本文基础上提供了更完善的集成。

使用 `zig fetch --save` 获取依赖（具体版本见 [Tags](https://github.com/zfl9/zmake/tags) 页面）：

```bash
# 引入 zmake 本身
zig fetch --save=zmake https://github.com/zfl9/zmake/archive/refs/tags/v1.3.0.tar.gz

# 引入 wolfssl 源码 tarball
zig fetch --save=wolfssl https://github.com/wolfSSL/wolfssl/archive/refs/tags/v5.9.2-stable.tar.gz
```

执行后 `build.zig.zon` 中将包含：

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .zmake = .{
            .url = "https://github.com/zfl9/zmake/archive/refs/tags/v1.3.0.tar.gz",
            .hash = "...",
        },
        .wolfssl = .{
            .url = "https://github.com/wolfSSL/wolfssl/archive/refs/tags/v5.9.2-stable.tar.gz",
            .hash = "...",
        },
    },
}
```

**build.zig** — 配置并构建：

```zig
const std = @import("std");
const ZMake = @import("zmake").ZMake;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wolfssl = ZMake.create(b, "wolfssl", .{
        .build_system_type = .autotools,
        .source_dir = b.dependency("wolfssl", .{}).path(""),
        .target = target,
        .optimize = optimize,
        .run_autogen = true,
    });
    wolfssl.add_configure_arg("--enable-tls13");
    wolfssl.add_configure_arg("--disable-oldtls");
    const build_out = wolfssl.build();

    // 导出命名路径，供下游 dependency 使用者引用
    b.addNamedLazyPath("include", build_out.path(b, "include"));
    b.addNamedLazyPath("lib", build_out.path(b, "lib"));

    // 安装头文件与库文件（zig build 时触发）
    b.installDirectory(.{
        .source_dir = build_out.path(b, "include"),
        .install_dir = .header,
        .install_subdir = "",
    });
    const install_lib = b.addInstallLibFile(build_out.path(b, "lib/libwolfssl.a"), "libwolfssl.a");
    b.getInstallStep().dependOn(&install_lib.step);
}
```

- ZMake 自动完成 wolfssl 的配置与构建，并与 Zig 的缓存系统紧密集成。
- 执行 `zig build`，编译产出在 `./zig-out/` 下，可见 include、lib 等文件。
- 执行 `zig build -Dtarget=...` 进行交叉编译，与原生的 Zig 使用方式一致。

## 支持的构建系统

| 类型 | 状态 |
|------|------|
| Autotools | ✅ 已完成 |
| CMake | 🚧 计划中 |
| Makefile | 🚧 计划中 |

## API 参考

### `ZMake`

#### `ZMake.create(b, name, options) → *ZMake`

| 参数 | 类型 | 说明 |
|------|------|------|
| `build_system_type` | `.autotools` / `.cmake` / `.makefile` | 上游构建系统类型 |
| `source_dir` | `LazyPath` | 源码目录路径 |
| `target` | `ResolvedTarget` | 编译目标（默认 host） |
| `optimize` | `OptimizeMode` | 优化模式（默认 ReleaseFast） |
| `lto` | `LtoMode` | LTO 模式（默认 none） |
| `separate_sections` | `bool` | `-ffunction-sections -fdata-sections`（默认 true） |
| `gc_sections` | `bool` | `-Wl,--gc-sections`（默认 true） |
| `strip` | `bool` | 是否剥离符号（默认根据 optimize 自动选择） |
| `run_autogen` | `bool` | 是否在 configure 前执行 autogen.sh（默认 false） |
| `install_prefix` | `[]const u8` | 逻辑安装前缀（默认 "/usr"） |
| `nproc` | `usize` | `make -j<N>` 并行数（默认使用当前的 CPU 核心数） |
| `build_dir_symlink` | `[]const u8` | 创建指向 `build_dir` 的符号链接（默认不创建） |

#### `zmake.add_configure_arg(arg: []const u8)`

添加额外的 `./configure` 参数（仅 Autotools）。

#### `zmake.build() → LazyPath`

执行构建，返回 **构建产出目录**（即 `{include, lib, ...}`）的 `LazyPath`。

#### `zmake.get_build_dir() → LazyPath`

获取指向 **构建目录** 的 `LazyPath`。只允许在 `build()` 之后调用。

#### `zmake.get_build_out() → LazyPath`

获取指向 **构建产出目录** 的 `LazyPath`。只允许在 `build()` 之后调用。

---

### `Pipeline`

依次执行多个系统命令或自定义 Step，Step 之间自动建立先后依赖关系。

#### `Pipeline.init(b, options) → Pipeline`

| 参数 | 类型 | 说明 |
|------|------|------|
| `cwd` | `LazyPath` | 系统命令执行时的工作目录（可选） |

#### `pipeline.add_command(program, options) → *Step.Run`

| 参数 | 类型 | 说明 |
|------|------|------|
| `name` | `[]const u8` | 步骤名称（可选） |
| `ignore_stdout` | `bool` | 捕获并忽略 stdout（默认 true） |

#### `pipeline.add_step(step: *std.Build.Step)`

将一个自定义 Step 追加到 Pipeline 末尾，自动依赖前一个步骤。

#### `pipeline.get_last_step() → *std.Build.Step`

返回 Pipeline 中最后一个 Step。

---

### `Symlink`

一个自定义的 `std.Build.Step`，用于在项目目录（build_root）下创建 **符号链接**。

#### `Symlink.create(b, symlink_filename, point_to_path) → *Symlink`

| 参数 | 类型 | 说明 |
|------|------|------|
| `symlink_filename` | `[]const u8` | 符号链接的文件名 |
| `point_to_path` | `LazyPath` | 符号链接指向的目标路径 |

> 注：`symlink_filename` 可以包含相对路径，程序将自动创建其目录。
