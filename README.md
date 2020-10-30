# n-traefik
Quick traefik setup on localhost

This is a quick and easy way to setup traefik on localhost to expose yur docker containers online.

First make sure you have a SSL certificate generated manually or go to https://seinopsys.dev/selfsigned to generate one that can be imported also in chrome

After you have downloaded the certificates , you can run the script by executing `traefik_setup.sh`. Before that make sure you have given execute permissions to the script.
To give execute permissions you can run

`chmod a+x traefik_setup.sh`

Follow the instructions of the script.

Import the certificate on the browser in order to remove the Certificate_error warning.
