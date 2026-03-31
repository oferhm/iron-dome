# iron_dome_game

A new Flutter project.

## Getting Started

flutter run -d emulator-5554

# for sound from emulator
# first add to path
$env:PATH += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"

adb shell settings put system volume_music_speaker 15

# if not working try 
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb shell settings put system volume_music_speaker 15
& $adb shell settings put system volume_music 15  
& $adb shell media volume --stream 3 --set 15
& $adb shell media volume --stream 1 --set 15

# debug for sound
flutter run -d emulator-5554 --verbose 2>&1 | findstr /i "sfx\|bgm\|load\|audio\|sound"
