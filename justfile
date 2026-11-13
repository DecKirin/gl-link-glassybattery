# GlassyBattery for GL-Link — https://github.com/casey/just

# gllink-ext, from GL-Link's extension SDK: `just ext help`
[positional-arguments]
ext *args:
    swift run gllink-ext "$@"

# The tests, and what GL-Link would say about the package
check:
    swift test
    swift run gllink-ext check GlassyBattery.ext

# Run it here against sample routers. It really talks to GlassyBattery on this Mac
run:
    swift run gllink-ext run GlassyBattery.ext

# Open it in GL-Link on this Mac, which asks before installing
install:
    swift run gllink-ext install GlassyBattery.ext

# Sign and pack it: build/GlassyBattery-<version>.glext (your key: `just ext keygen`)
build:
    swift run gllink-ext build GlassyBattery.ext -o build

# Build it, release it here on GitHub, and write its marketplace entry into build/
publish:
    swift run gllink-ext publish GlassyBattery.ext -o build

# The script API, for the editor
types:
    swift run gllink-ext types > gllink.d.ts
