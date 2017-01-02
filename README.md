
           ,;;;,
          ;;;;;;;
       .-'`\, '/_
     .'   \ ("`(_)  TRAVMO - Travis Service Monitoring
    / `-,.'\ \_/
    \  \/\  `--`
     \  \ \
      / /| |  Author: Lukas Matt <lukas@zauberstuhl.de>
     /_/ |_|
    ( _\ ( _\

This is a service monitoring tool. You can write tests in bash  
and get notified via Email if something is wrong  
or a test just recovered from the critical state!

Have a look at the `test/` folder for some examples.

# Configuration

Trigger a rebuild via travis API requires a token which we have to store in `.travis.yml`:

    cd status/
    travis login --org
    travis token --org
    # copy the token from your terminal
    travis encrypt travistoken="<REPLACE-WITH-TOKEN>" --add

If you want to use the email notification service in `test/05_aws-ses.test`  
you have to adjust the file and change the smtp server and add your account details to `.travis.yml` as well

    travis encrypt smtpauthuser="<REPLACE-WITH-SMTP-USERNAME>" --add
    travis encrypt smtpauthpassword="<REPLACE-WITH-SMTP-PASSWORD>" --add

If you want to use the status page in the `gh-pages` branch you have to adjust the `index.html`  
and create a ssh key for your repository. This is necessary to be able to track the current status!

If you generated a new ssh key add it to your repository keys and put it into `.travis.yml` as well:

    base64 --wrap=0 id_rsa > id_rsa_base64
    split --bytes=100 --numeric-suffixes --suffix-length=2 id_rsa_base64 id_rsa_
    for file in $(ls id_rsa_*); do travis encrypt $file="$(cat $file)" --add; rm $file; done

Now travis should be able to update your repository automatically and safe all results into the `monitoring` branch!

# Usage

Add new tests to the `test/` directory and push it into the master branch.  
Make sure that travis is not running. Otherwise you will end up with two travis tests.
