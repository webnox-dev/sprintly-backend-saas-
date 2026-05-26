@echo off
echo Starting pub get... > pub_log.txt
dart pub get --verbose >> pub_log.txt 2>&1
echo DONE >> pub_log.txt
