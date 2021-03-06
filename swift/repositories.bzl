# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Definitions for handling Bazel repositories used by the Swift rules."""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _create_linux_toolchain(repository_ctx):
    """Creates BUILD targets for the Swift toolchain on Linux.

    Args:
      repository_ctx: The repository rule context.
    """
    if repository_ctx.os.environ.get("CC") != "clang":
        fail("ERROR: rules_swift uses Bazel's CROSSTOOL to link, but Swift " +
             "requires that the driver used is clang. Please set `CC=clang` in " +
             "your environment before invoking Bazel.")

    path_to_swiftc = repository_ctx.which("swiftc")
    path_to_clang = repository_ctx.which("clang")
    root = path_to_swiftc.dirname.dirname

    repository_ctx.file(
        "BUILD",
        """
load(
    "@build_bazel_rules_swift//swift/internal:swift_toolchain.bzl",
    "swift_toolchain",
)

package(default_visibility = ["//visibility:public"])

swift_toolchain(
    name = "toolchain",
    arch = "x86_64",
    clang_executable = "{path_to_clang}",
    os = "linux",
    root = "{root}",
)
""".format(
            path_to_clang = path_to_clang,
            root = root,
        ),
    )

def _create_xcode_toolchain(repository_ctx):
    """Creates BUILD targets for the Swift toolchain on macOS using Xcode.

    Args:
      repository_ctx: The repository rule context.
    """
    repository_ctx.file(
        "BUILD",
        """
load(
    "@build_bazel_rules_swift//swift/internal:xcode_swift_toolchain.bzl",
    "xcode_swift_toolchain",
)

package(default_visibility = ["//visibility:public"])

xcode_swift_toolchain(
    name = "toolchain",
)
""",
    )

def _swift_autoconfiguration_impl(repository_ctx):
    # TODO(allevato): This is expedient and fragile. Use the platforms/toolchains
    # APIs instead to define proper toolchains, and make it possible to support
    # non-Xcode toolchains on macOS as well.
    os_name = repository_ctx.os.name.lower()
    if os_name.startswith("mac os"):
        _create_xcode_toolchain(repository_ctx)
    else:
        _create_linux_toolchain(repository_ctx)

_swift_autoconfiguration = repository_rule(
    environ = ["CC", "PATH"],
    implementation = _swift_autoconfiguration_impl,
)

def _maybe(repo_rule, name, **kwargs):
    """Executes the given repository rule if it hasn't been executed already.

    Args:
      repo_rule: The repository rule to be executed (e.g., `git_repository`.)
      name: The name of the repository to be defined by the rule.
      **kwargs: Additional arguments passed directly to the repository rule.
    """
    if name not in native.existing_rules():
        repo_rule(name = name, **kwargs)

def swift_rules_dependencies():
    """Fetches repositories that are dependencies of the `rules_swift` workspace.

    Users should call this macro in their `WORKSPACE` to ensure that all of the
    dependencies of the Swift rules are downloaded and that they are isolated from
    changes to those dependencies.
    """
    _maybe(
        git_repository,
        name = "bazel_skylib",
        remote = "https://github.com/bazelbuild/bazel-skylib.git",
        tag = "0.5.0",
    )

    _maybe(
        http_archive,
        name = "com_github_apple_swift_swift_protobuf",
        urls = ["https://github.com/apple/swift-protobuf/archive/1.2.0.zip"],
        strip_prefix = "swift-protobuf-1.2.0/",
        type = "zip",
        build_file = "@build_bazel_rules_swift//third_party:com_github_apple_swift_swift_protobuf/BUILD.overlay",
    )

    _maybe(
        http_archive,
        name = "com_google_protobuf",
        # v3.6.1.2, latest as of 2018-12-04
        urls = ["https://github.com/protocolbuffers/protobuf/archive/v3.6.1.2.zip"],
        strip_prefix = "protobuf-3.6.1.2",
        type = "zip",
    )

    _maybe(
        _swift_autoconfiguration,
        name = "build_bazel_rules_swift_local_config",
    )
