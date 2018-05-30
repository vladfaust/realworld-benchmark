# RealWorld Benchmark

This is a benchmark for a [RealWorld](https://realworld.io) back-end API implementation.

## Installation

It's a [Crystal](https://crystal-lang.org) application, so you'll need to have Crystal installed on the machine. It also relies on [wrk](https://github.com/wg/wrk), which is mandatory.

## Usage

`crystal src/realworld-benchmark.cr --release --no-debug --progress -- --host=localhost -p 5000`

## Contributors

- [@vladfaust](https://github.com/vladfaust) Vlad Faust - creator, maintainer
