#! /bin/sh

fileName=${1}

cat $ENV_INPUTFILE > $fileName
cat $ENV_TEXTINPUT >> $fileName

echo "Successfully uploaded file and appended text to file. You can find your file in the storage directory."
