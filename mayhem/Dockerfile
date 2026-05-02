FROM golang:1.25 AS builder

RUN apt-get update && apt-get install -y clang && rm -rf /var/lib/apt/lists/*

RUN go install github.com/dvyukov/go-fuzz/go-fuzz@latest github.com/dvyukov/go-fuzz/go-fuzz-build@latest

COPY . /consul-terraform-sync
WORKDIR /consul-terraform-sync
RUN GOFLAGS=-mod=mod go get github.com/dvyukov/go-fuzz/go-fuzz-dep@latest
RUN go-fuzz-build -libfuzzer -o fuzz.a ./mayhem/
RUN clang -fsanitize=fuzzer fuzz.a -o fuzz.libfuzzer

FROM debian:bookworm-slim
COPY --from=builder /consul-terraform-sync/fuzz.libfuzzer /fuzz.libfuzzer
