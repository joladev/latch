# Latch

atproto OAuth library attempting to follow the specification strictly, while also following Elixir library guidelines. The goal is for the library to be easy to use and not get in your way, but fully flexible.

This is a pretty extensive introduction to atproto OAuth [Beyond the Statusphere: Part 2, ATProto OAuth, the TLDR](https://leaflet.pub/77df80c7-ec7e-4728-afa9-e367d99adb97). The core of this code originates from [annot.at](https://annot.at).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `latch` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:latch, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/latch>.

## Roadmap

- [x] Confidential client
- [x] DPoP nonce caching
- [ ] Public client
- [ ] Local client
- [ ] Extensive tests

## Specification references

* https://docs.bsky.app/docs/advanced-guides/oauth-client
* https://atproto.com/specs/oauth
