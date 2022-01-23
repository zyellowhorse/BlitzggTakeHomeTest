# My Approach to Blitz.gg Webhook Take Home Test

I will be documenting my thought process and my approach to solving the Blitz.gg Webhook Take Home Test. The requirements for the test can be found here [here](Blitz_DevOps_Take_Home_Test.pdf). This is meant to be ancillary to the objective as well as to my commit messages. This is to show my thought process and to show the order on of how I approached the problems. 

## Webhook container setup

After reading over the [requirements](Blitz_DevOps_Take_Home_Test.pdf) and the [Webhook](https://github.com/adnanh/webhook) README I decided to start off by looking up a quick [video](https://www.youtube.com/watch?v=Qw9zlE3t8Ko) on youtube to refresh myself on docker compose. Their README shows that they have an image on docker hub that I can use. I created a simple docker-compose.yml file to begin with which looks like this:
```yaml
version: '3'

services:
  webhook:
    image: almir/webhook
    command: -verbose
```

I wanted to make sure that the container works and I passed in the verbose flag so that the container will say alive. 

The next steps would be to add some volumes to the docker-compose file so that I can pass in data to the container for the hook endpoints and the script that the hook is going to call. I also need to add a volume to keep my persistent data so that the data is the same even after docker compose up and down. 
I updated the docker compose file to look like so:
```yaml
version: '3'

services:
  webhook:
    image: almir/webhook
    command: -hotreload
    volumes:
      - ./hooks.json:/etc/hooks/hooks.json
      - ./scripts:/var/scripts/
      - ./storage:/storage/
```

## Hooks setup

I created the hooks.json file as well as created a scripts and storage directory. My hooks.json file looks like this: 
```json
[
  {
    "id": "append-text",
    "execute-command": "/var/scripts/append-text.sh",
    "command-working-directory": "/storage"
  }
]
```

I created this file based up on reading their documentation. Webhook will create an endpoint based upon the id in the hooks.json file. Basically whenever append-text endpoint is hit it will call the append-text.sh script. 

## Script Setup

Now I am going to create a basic bash script to append to the end of a file. The file is going to live in the scripts directory and I named it append-text.sh, here is what it looks like:
```bash
#! /bin/bash

echo "This is a new line" >> example.txt
```

This should be good enough for some basic testing. Now that I have hooks.json setup and an append-text.sh file if all goes well I can use `docker-compose up -d` to run the docker container. This will read in my hooks.json file and create an endpoint for append-text on localhost. If I hit the endpoint localhost:9000/hooks/append-text it should run my append-text.sh script and an example.txt file should appear in ./storage directory with text written to it saying "This is a new line".

When I tested it didn't work. I forgot to add a port in the docker compose section so that I could hit it from my localhost and my location where I was placing the hooks.json file was incorrect which I had to double check with the documentation. I had to update it to be /etc/webhook/hooks.json.
Here is what my updated docker-compose.yml file looks like:
```yaml
version: '3'

services:
  webhook:
    image: almir/webhook
    ports:
      - 9000:9000
    command: -verbose -hotreload
    volumes:
      - ./hooks.json:/etc/webhook/hooks.json
      - ./scripts:/etc/scripts/
      - ./storage:/storage/
```

When I started it again I was able to get it to run I was able to get the append-text endpoint on localhost but Webhook showed errors that it wasn't able to find the append-text.sh file. To troubleshoot this I exec in to the container and looked to see how my path to the scripts was different from what the error message said. After reading it I saw that my paths were incorrect between where I was placing the scripts and where the hooks.json file was looking. The hooks.json file was looking in /var/scripts but I placed them in /etc/scripts. I updated the hooks.json file to be /etc/scripts.

After that I got a new error saying "permission denied". I updated the script to an executable with `chmod +x append-text.sh`. After that I got a new error saying "not found" this was because the shebang was looking for /bin/bash which the container did not have it only has sh. I update the shebang to use sh instead of bash.
```sh
#! /bin/bash
to 
#! /bin/sh
```

Now that all of that was done I got a working example where if I go to the append-text endpoint example.txt shows up in the storage directory. I tested hitting the endpoint multiple times and it successfully appends to the end of the file. 

## File Input and save

The next thing to tackle is accepting a file name, there's an example in their documentation that I was able to follow found [here](https://github.com/adnanh/webhook/blob/master/docs/Hook-Examples.md#pass-file-to-command-sample). I updated my hooks.json to look similar to theirs which resulted in looking like this:
```json
[
  {
    "id": "append-text",
    "execute-command": "/etc/scripts/append-text.sh",
    "command-working-directory": "/storage",
    "pass-file-to-command":
    [
        {
            "source": "payload",
            "name": "binary",
            "envname": "ENV_INPUTFILE",
            "base64decode": true,
        }
    ],
    "include-command-output-in-response": true
  }
]
```

Reading over the pass-file-to-command property it looks like it deletes the files once it exits and the data types its takes in has to be json or form-value encoded when using the payload source. The properties and request value information can be found [here](https://github.com/adnanh/webhook/blob/master/docs/Hook-Definition.md) and [here](https://github.com/adnanh/webhook/blob/master/docs/Referencing-Request-Values.md). 

## Prompt script creation

My initial thinking is that I will create a script to prompt for file name then encode that file in base64 then append that to a basic json payload. I will send that payload to the webhook endpoint using curl which I believe the webhook will do the work to decode it then the script will take that and save to a file in persistent storage. I think this approach will work for running it locally or the script will need to exist on machines calling this webhook for easability. If not then other machines will need to encode the payload before sending it by whatever means. 

Starting with this approach I had to look the up the syntax again for prompting for user input in bash. I also had to look up how to encode a text file as base64. After some remembering how to write bash I was able to create a script that will take in put for the file, encode it in base64, add it to a payload, send a curl request to the webhook. I named the file `append-text` and the contents look like this:
```bash
#!/bin/bash

fullPathTextFile=""

echo "Enter full path or relitive path to text file: "
read textFileInput

if [ "$textFileInput" == "" ]
then
    echo "Please enter path to text file"
    exit 1
fi

if [[ "$textFileInput" == /* ]]
then
    fullPathTextFile="$textFileInput"
elif [[ "$textFileInput" != /* ]]
then
    fullPathTextFile=$(pwd)"/$textFileInput"
else
    echo "Unable to read file path"
    exit 1
fi

encodedFile=$(base64 $fullPathTextFile)
payload="{\"binary\":\"$encodedFile\"}"

curl -H "Content-Type:application/json" -X POST -d $payload http://localhost:9000/hooks/append-text

exit 0
```

Now that this part works I am going to update the append-text.sh file in the scripts directory to read the environment variable created by the webhook and save it to persistence storage. I updated the script and its working as intended but still only saving the file as output.txt which I will address later on. I also have the script responding to the request with a successful message. My append-text.sh file looks like this now:
```sh
#! /bin/sh

cat $ENV_INPUTFILE >> outputfile.txt

echo "Successfully uploaded file and appended text to file. You can find your file in the storage directory."
```

I am now able to run `./append-text` which will prompt me for a file name and once supplied it will make a POST request to the webhook to save the file to the persistent storage. 

## Append text Input and file save name

The next thing to address is input for text that the user wants to append to their file. I will also want to look into addressing the name of the file when saved to persistent storage. For adding a string for what to append to the file I will prompt for that as well as pass that in the payload to the webhook / script. 

I updated append-text to prompt for some user input of what they want to append to the file. I actually ran into an issue where once I added more text to my text file I was testing with the base64 encoding output was adding new lines thus breaking the curl command. To fix this I updated the base64 commands to have `-w 0` as an argument so that it will not add new lines. I added a check to make sure that the file path passed in exists. My updated append-text looks like this:
```sh
#!/bin/bash

fullPathTextFile=""

echo "Enter full path or relitive path to text file: "
read textFileInput

echo "Type the text you wish to append to the end of the file"
read userTextInput

if [ "$textFileInput" == "" ]
then
    echo "Please enter path to text file"
    exit 1
fi

if [[ "$textFileInput" == /* ]]
then
    fullPathTextFile="$textFileInput"
elif [[ "$textFileInput" != /* ]]
then
    fullPathTextFile=$(pwd)"/$textFileInput"
else
    echo "Unable to read file path"
    exit 1
fi

if [[ -f "$fullPathTextFile"  ]]
then
    encodedTextFile=$(base64 -w 0 $fullPathTextFile)
else
    echo "File does not exits. Looking for: $fullPathTextFile"
    exit 1
fi
encodedUserTextInput=$(echo $userTextInput | base64 -w 0)
payload="{\"binary\":\"$encodedTextFile\",\"textinput\":\"$encodedUserTextInput\"}"

curl -H "Content-Type:application/json" -X POST -d $payload http://localhost:9000/hooks/append-text

exit 0
```

For hooks.json I added another section to read the payload for the section textinput and create an environment variable from it. I am then appending that text to the end of the original file. My hooks.json file looks like this:
```json
[
  {
    "id": "append-text",
    "execute-command": "/etc/scripts/append-text.sh",
    "command-working-directory": "/storage",
    "pass-file-to-command":
    [
        {
            "source": "payload",
            "name": "binary",
            "envname": "ENV_INPUTFILE",
            "base64decode": true,
        },
        {
            "source": "payload",
            "name": "textinput",
            "envname": "ENV_TEXTINPUT",
            "base64decode": true,
        }
    ],
    "include-command-output-in-response": true
  }
]
```

Lastly I added another part to the scripts/append-text.sh, which looks like so:
```sh
#! /bin/sh

cat $ENV_INPUTFILE >> outputfile.txt

cat $ENV_TEXTINPUT >> outputfile.txt

echo "Successfully uploaded file and appended text to file. You can find your file in the storage directory."
```

I have tested this and it works as intended. Another thing I wanted to address was passing the file name to the script so that its not saving it outputfile.txt and instead the actual name of the file. Like always I am going to start out with the append-text file, luckily I am already getting the input from the user I just need to sanitize it then add it to the payload. This was mad easy by utilizing the `basename` command to give me the name of the file. Here is what my append-text file looks like:
```bash
#!/bin/bash

fullPathTextFile=""

echo "Enter full path or relitive path to text file: "
read textFileInput

echo "Type the text you wish to append to the end of the file"
read userTextInput

if [ "$textFileInput" == "" ]
then
    echo "Please enter path to text file"
    exit 1
fi

if [[ "$textFileInput" == /* ]]
then
    fullPathTextFile="$textFileInput"
elif [[ "$textFileInput" != /* ]]
then
    fullPathTextFile=$(pwd)"/$textFileInput"
else
    echo "Unable to read file path"
    exit 1
fi

if [[ -f "$fullPathTextFile"  ]]
then
    encodedTextFile=$(base64 -w 0 $fullPathTextFile)
else
    echo "File does not exits. Looking for: $fullPathTextFile"
    exit 1
fi

fileName="$(basename $fullPathTextFile)"
encodedUserTextInput=$(echo $userTextInput | base64 -w 0)
payload="{\"binary\":\"$encodedTextFile\",\"textinput\":\"$encodedUserTextInput\",\"filename\":\"$fileName\"}"

curl -H "Content-Type:application/json" -X POST -d $payload http://localhost:9000/hooks/append-text

exit 0
```

Next the hooks.json. Here I added a new argument for "pass-arguments-to-command" which allows me to pass the argument of -f filename to the script. the filename will be pulled from the payload. Here is how the file looks now:
```json
[
  {
    "id": "append-text",
    "execute-command": "/etc/scripts/append-text.sh",
    "command-working-directory": "/storage",
    "pass-file-to-command":
    [
        {
            "source": "payload",
            "name": "binary",
            "envname": "ENV_INPUTFILE",
            "base64decode": true,
        },
        {
            "source": "payload",
            "name": "textinput",
            "envname": "ENV_TEXTINPUT",
            "base64decode": true,
        }
    ],
    "pass-arguments-to-command":
    [
        {
            "source": "payload",
            "name": "filename"
        }
    ],
    "include-command-output-in-response": true
  }
]
```

And now time for the script/append-text.sh file. I setup hooks.json to pass the argument to the script itself so I have to update to accept the argument. I also updated it so that it will overwrite the file if it exits and append afterwards. I added that in and now the file looks like so:
```sh
#! /bin/sh

fileName=${1}

cat $ENV_INPUTFILE > $fileName
cat $ENV_TEXTINPUT >> $fileName

echo "Successfully uploaded file and appended text to file. You can find your file in the storage directory."
```

After all that was done I was able to pass in the file and have it append text correctly and save the file with the same name. 

## Networking

Now its time to look at the networking side of the challenge. So far I have had docker-compose bring up the webhook container and serve its endpoints on localhost. One of the challenges is to test the webhook from outside the webhook container but not on localhost. Right now my setup is that I have the webhook container running on docker in a WSL instance which the way its setup localhost can route to the instances on WSL. I don't believe this is sufficient because it explicitly says not localhost. To test this I am going to create another container and pass the append-text file to it. This way It will be within network of docker and not localhost. I believe by default docker puts all containers on the same network bridge so this should be easy to communicate between the containers. Even though they will most likely be put on the same network I am going to have the docker-compose create a network and have the two containers use it. 

Usually when I am testing stuff with docker I don't have to create a network or if I do I end up doing it manually and not through docker-compose so I had to look up the documentation on how to create a network found [here](https://docs.docker.com/compose/networking/). 

> By default Compose sets up a single [network](https://docs.docker.com/engine/reference/commandline/network_create/) for your app. Each container for a service joins the default network and is both _reachable_ by other containers on that network, and _discoverable_ by them at a hostname identical to the container name.

Looks like even in compose it creates a network to place all the services. I am still going to create a network just to be explicate. The new container is going to be a ubuntu image with append-text and exampleFile.txt added to it. While updating the docker-compose file I had to look up how to keep the ubuntu image alive because usually the container is running something. I found that I can use `tail -f /dev/null` to keep it alive for this test. After all the updates here is what my docker-compose.yml file looks like now:
```yaml
version: '3'

services:
  webhook:
    image: almir/webhook
    ports:
      - 9000:9000
    command: -verbose -hotreload
    volumes:
      - ./hooks.json:/etc/webhook/hooks.json
      - ./scripts:/etc/scripts
      - ./storage:/storage
    networks:
      - customNetwork

  testContainer:
    image: ubuntu
    command: tail -f /dev/null
    volumes:
      - ./append-text:/usr/bin/append-text
      - ./exampleFile.txt:/exampleFile.txt
    networks:
      - customNetwork

networks:
  customNetwork:
```

The next thing to update is append-text because its curling localhost where if ran on the ubuntu container it want able to find it. I need to update it to the name that will resolve inside the customNetwork which by default is the name of the service so 'webhook'. I changed the curl command to look like this:
```bash
curl -H "Content-Type:application/json" -X POST -d $payload http://localhost:9000/hooks/append-text
# to
curl -H "Content-Type:application/json" -X POST -d $payload http://webhook:9000/hooks/append-text
```

With that done I ran ran docker-compose and it was all running. I exec'ed into the ubuntu container to test append-text but it looks like curl isn't installed which makes sense so I will switch to a different image which has it already preinstalled. I switched out ubuntu with mikesir87/ubuntu-with-curl because it had curl already installed which will make it easier to run append-text file. Testing from inside the other container I am able to run append-text successfully as if I was running it on localhost. 

I wanted to make it so that append-text can be run either looking at localhost or within another container so I updated the curl command to test both and add -s to silence the output since one is going to fail. It looks like this now inside append-text:
```bash
curl -H "Content-Type:application/json" -X POST -d $payload http://webhook:9000/hooks/append-text
# to
curl -s -H "Content-Type:application/json" -X POST -d $payload http://webhook:9000/hooks/append-text || curl -s -H "Content-Type:application/json" -X POST -d $payload http://localhost:9000/hooks/append-text
```

I tested it both inside and outside the container and it works for both now with the same append-text file. 

## Webhook endpoint security

Now its time to look at securing the endpoint so that not just anything can hit it to trigger the script. I remember reading about some security options from the documentation but decided to skip over that because that would come later for me. I will take a look at those to see what I might want to do but I have some ideas to begin with. 

I think I might want to see if I can create a webhook that would create a token and associate it to an IP that requested it and save the key value pair to a flat file to emulate a database. Then when going to the append-text endpoint it would need to supply the token in the header of the request. If there isn't' a token or it does not match or exist in the flat file reject the request. I know I'm over complicating it for this test but I think this approach might be fun. I will also look into adding other types of security.

### Token generation
To begin with I'm going to update the append-text to send a token in the header then update the hook to pass it to the script. I'm going to update append-text.sh file to print out the token. This is to just test that I am able to successfully send a token and have it be passed to the script. I will look into adding another endpoint to generate the token / flat flie stuff later. 

I updated append-text to add a header for Authorization with the string ABC123ABC as my token. It looked like this:
```bash
... -H "Authorization: ABC123ABC" ...
```

I also update the hooks.json to pass the token to the script from heading the header like so:
```json
...
{
	"source": "header",
	"name": "Authorization"
}
...
```

I then added echo statement to the append-text.sh to see the token. I tested it and everything worked so we are all good there. 

Now its time to create the endpoint to generate the token when hit. I updated the hooks.json to create a new endpoint called get-token here is what it looks like:
``` json
...
{
	"id": "get-token",
	"execute-command": "/etc/scripts/get-token.sh",
	"command-working-directory": "/tmp",
	"pass-arguments-to-command":
	[
		{
			"source": "request",
			"name": "remote-addr"
		}
	],
	"include-command-output-in-response": true
}
...
```

I figured out that I can get the remote address from the request from their documentation [here](https://github.com/adnanh/webhook/blob/master/docs/Referencing-Request-Values.md). 

Now its time to create the get-token.sh script that its calling. First I am going to check if tokenList.txt file exists or not and if not create it. I am then going to read the file line by line looking to see if the remote address exists in there or not. If it does return its token if it doesn't then create a token save it to a file with the remote address and return the token. 

I had to look how to create a string to with number and letters to that it can be a token which I found out this command will do it `cat /proc/sys/kernel/random/uuid | sed 's/[-]//g' | head -c 20; echo;`. I added that in to create a token if the remote address does not exist in the file. My get-token.sh script ended up looking like this:
```sh
#! /bin/sh

requestRemoteAddr=$1
tokenListFilePath="/tmp/tokenList.txt"

touch $tokenListFilePath

while IFS="=" read -r remoteAddr token
do
    if [ "$remoteAddr" = "$requestRemoteAddr" ]
    then
        echo $token
        exit 0
    fi
done < $tokenListFilePath

token=$(cat /proc/sys/kernel/random/uuid | sed 's/[-]//g' | head -c 20; echo;)

echo "$requestRemoteAddr=$token" >> "$tokenListFilePath"

echo $token
exit 0
```

Testing this locally and it successfully creates a token if the ip I pass in does not exist as well as will return the already existing token if it does exist.

I need to update the append-text file to hit that endpoint to get a token and then send that token in the header of my append-text request. My append-text file looks like this now:
```bash
#!/bin/bash

fullPathTextFile=""

echo "Enter full path or relitive path to text file: "
read textFileInput

echo "Type the text you wish to append to the end of the file"
read userTextInput

if [ "$textFileInput" == "" ]
then
    echo "Please enter path to text file"
    exit 1
fi

if [[ "$textFileInput" == /* ]]
then
    fullPathTextFile="$textFileInput"
elif [[ "$textFileInput" != /* ]]
then
    fullPathTextFile=$(pwd)"/$textFileInput"
else
    echo "Unable to read file path"
    exit 1
fi

if [[ -f "$fullPathTextFile"  ]]
then
    encodedTextFile=$(base64 -w 0 $fullPathTextFile)
else
    echo "File does not exits. Looking for: $fullPathTextFile"
    exit 1
fi

authToken=$(curl -s http://webhook:9000/hooks/append-text || curl -s http://localhost:9000/hooks/append-text)

fileName="$(basename $fullPathTextFile)"
encodedUserTextInput=$(echo $userTextInput | base64 -w 0)
payload="{\"binary\":\"$encodedTextFile\",\"textinput\":\"$encodedUserTextInput\",\"filename\":\"$fileName\"}"

uploadResponse=$(curl -s -H "Content-Type:application/json" -H "Authorization: $token" -X POST -d $payload http://webhook:9000/hooks/append-text || curl -s -H "Content-Type:application/json" -H "Authorization: $token" -X POST -d $payload http://localhost:9000/hooks/append-text)

exit 0
```

I also had to update my append-text.sh file so that it will check if the token supplied exists in the tokenList file and if ti does then save the file and append text. Here is what append-text.sh file looks like now:
```sh
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
```

When I tested this out I didn't work it was constantly getting the error saying to supply a valid authToken. I looked at the webhook output and it looks like whenever I make a request from localhost its done on a different port each time. This was causing the request address to be different thus me no longer having a valid token. To fix this I am going to remove the port portion of request address when saving the key value pair to the tokenLIst file. Here is what I changed in get-token.sh:
```sh
requestRemoteAddr=$1
#to
requestRemoteAddr=$(echo $1 | cut -d: -f1)
```

After that changed and it works now. The tokens it generates are unique, it returns the token if the request address is the same, the append-text.sh validates that the supplied token exists. Since the tokenList is supposed to emulate a database I would save that to persistent storage but for this small test I will keep it as tmp and have it be created upon docker-compose up and down. this way I can show off the unique tokens and nothing is hard coded. 

I would think this is enough security, the token stuff would ideally be replaced with an actual token generating service and database. Plus its not much security because if you don't supply a token it tells you were to go to get one. 

### Trigger rule security
Now its time to approach the security aspect as I believe it was intended to be done. Webhook has a property called "trigger-rule" which you can specify so that certain conditions are met before running the script. I think I am going to follow the example they have in their documentation found [here](https://github.com/adnanh/webhook/blob/master/docs/Hook-Examples.md#a-simple-webhook-with-a-secret-key-in-get-query). It shows how trigger-rule is used to validate a value in the url specifically token. I will do the same with a static token saved in a file. 

Here will be my approach; update hooks.json to have a trigger rule looking at the URL and matching the value of the token. I will update the append-text file to read in the static token file and added it to the end of the append-text URL. This way it will only run if the static token is passed in through the URL.

I started off by updating the hooks.json file adding the trigger rule as well as some other properties to narrow its scope. Here is who it looks like now:
```json
[
    {
        "id": "append-text",
        "execute-command": "/etc/scripts/append-text.sh",
        "command-working-directory": "/storage",
        "pass-file-to-command":
        [
            {
                "source": "payload",
                "name": "binary",
                "envname": "ENV_INPUTFILE",
                "base64decode": true,
            },
            {
                "source": "payload",
                "name": "textinput",
                "envname": "ENV_TEXTINPUT",
                "base64decode": true,
            }
        ],
        "pass-arguments-to-command":
        [
            {
                "source": "payload",
                "name": "filename"
            },
            {
                "source": "header",
                "name": "Authorization"
            }
        ],
        "include-command-output-in-response": true,
        "incomming-payload-conten-type": "application/json",
        "http-methods": ["POST"],
        "trigger-rule":
        {
            "match":
            {
                "type": "value",
                "value": "bbbc4488fda14e63828d",
                "parameter":
                {
                    "source": "url",
                    "name": "token"
                }
            }
        }
    },
    {
        "id": "get-token",
        "execute-command": "/etc/scripts/get-token.sh",
        "command-working-directory": "/tmp",
        "pass-arguments-to-command":
        [
            {
                "source": "request",
                "name": "remote-addr"
            }
        ],
        "include-command-output-in-response": true,
        "http-methods": ["GET"]
    }
]
```

I then added created the staticToken.txt file in the same directory with the same value as the token shown in the trigger rule of hooks.json

I need to update the append-text file so that it will read the staticToken.txt file then add that to the end of the url of append-token. Here is what the append-text file looks like now: 
```bash
#!/bin/bash

fullPathTextFile=""
staticToken=""

echo "Enter full path or relitive path to text file: "
read textFileInput

echo "Type the text you wish to append to the end of the file"
read userTextInput

if [ "$textFileInput" == "" ]
then
    echo "Please enter path to text file"
    exit 1
fi

if [[ "$textFileInput" == /* ]]
then
    fullPathTextFile="$textFileInput"
elif [[ "$textFileInput" != /* ]]
then
    fullPathTextFile=$(pwd)"/$textFileInput"
else
    echo "Unable to read file path"
    exit 1
fi

if [[ -f "$fullPathTextFile"  ]]
then
    encodedTextFile=$(base64 -w 0 $fullPathTextFile)
else
    echo "File does not exits. Looking for: $fullPathTextFile"
    exit 1
fi

if [[ "$pwd" == "/" ]]
then
    staticTokenPath="/staticToken.txt"
else
    staticTokenPath=$(pwd)"/staticToken.txt"
fi

staticToken=$(cat $staticTokenPath)
authToken=$(curl -s http://webhook:9000/hooks/get-token || curl -s http://localhost:9000/hooks/get-token)

fileName="$(basename $fullPathTextFile)"
encodedUserTextInput=$(echo $userTextInput | base64 -w 0)
payload="{\"binary\":\"$encodedTextFile\",\"textinput\":\"$encodedUserTextInput\",\"filename\":\"$fileName\"}"

curl -s -H "Content-Type:application/json" -H "Authorization: $authToken" -X POST -d $payload http://webhook:9000/hooks/append-text?token=$staticToken || curl -s -H "Content-Type:application/json" -H "Authorization: $authToken" -X POST -d $payload http://localhost:9000/hooks/append-text?token=$staticToken

exit 0
```

I also need to update the docker-compose file so that the staticToken.txt file is added to the other container so that it can be used for running the append-text file. I tested both inside and outside the container and this works. 

## Finishing touches
I believe I have now addressed all the bullet points on the test aside from the README portion but I will be putting all of that in the README file and not here. My webhook takes in the name of a text file and text to append to the end of a text file. The file is written to persistent storage that persists docker-compose up and down. The endpoint can be hit from localhost as well as from another container within the same network. My webhook has two forms of security one where it uses trigger rules with a static token passed in through the URL. The other where it create a dynamic token and it checks to make sure that token exists in the "database" before running. 

Since the document mentions that the user should be running command but rather scripts I will create a script that just runs `docker-compose up -d`. I named the script start-environment. I also made another one for taking down the environment which is just compose down name stop-environment. 

The only other thing would be I need to make a script for if a user wanted to test from inside the container they can run a script to do that. I create append-text-inside-container which houses this command `docker exec -it testContainer append-text`. Running this script will just run the append-text inside the container. 

## Ending thoughts

Overall I had fun with this test I got to use webhook repo that I have not used before. I've used webhooks before by other services like calling one to send a message in a Teams channel but never set one up myself. As far as my implementation I think I did pretty well, there are something that could be improved but I feel like this is good for a take home test. There are some things that I can think of as potential issues one is that this wont work on windows machines and some of the paths expect the file to be there or the script might fail. An example of this might be if the user types ./<filename> it might not know how to deal with that also the staticToken.txt file needs to be in a relative path. Also not just validating the authToken exists but its associated with the same IP. These things can be notated in the README through so not too worried about it. Again I am happy with what I ended up with and had fun with this project. 
