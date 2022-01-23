#! /bin/sh

fileName=${1}
authToken=${2}
tokenListFilePath="/tmp/tokenList.txt"

touch $tokenListFilePath

if [ "$authToken" = "" ]
then
    echo "Please supply an authToken in Authorization hearder. Hit get-token endpoint to get one"
    exit 0
fi

while IFS="=" read -r remoteAddr token
do
    if [ "$authToken" = "$token" ]
    then
        cat $ENV_INPUTFILE > $fileName
        cat $ENV_TEXTINPUT >> $fileName
        echo "Successfully uploaded file and appended text to file. You can find your file in the storage directory."
        exit 0
    fi
done < $tokenListFilePath

echo "Please supply a valid authToken"
exit 0
