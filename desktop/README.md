# desktop

run on mac m2

```sh
brew install sdl2

export LIBRARY_PATH="$LIBRARY_PATH:/opt/homebrew/lib"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/homebrew/lib"
export DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH:/opt/homebrew/lib"

cargo run -r
```

anvil

```
anvil -b 1 --no-request-size-limit --disable-block-gas-limit --disable-code-size-limit --disable-min-priority-fee
```
