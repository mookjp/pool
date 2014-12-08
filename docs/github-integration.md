Integrate Pool service with GitHub
===================================

 This feature provides some integration(ex: notification, etc..) with GitHub service.

Features
---------

 Implemented github integration supports the features below;

- If new pull request is opened on target github repository you specified in `Vagrantfile`, and `github_bot` service crawl and find the event, then `github_bot` comments preview url (ex: `http://development.pool.dev`) on the pull request.

How to use
-----------

1. Before `vagrant up` to initialize pool service, put GitHub access token on `./docker/pool/config/config.yml`.

  ```
  $ cd docker/pool/config/
  $ cp config.yml.sample config.yml
  $ vi config.yml # put your github access token
  $ cat config.yml
  GITHUB_ACCESS_TOKEN: "put your access token here"
  ```

2. In `Vagrantfile`, enable `--github-bot` option;

  ```
  ...
  # If you'd like to enable github integration, uncomment below
  # s.args << "--github-bot"
  ...
  ```

3. Start the vagrant VM includes pool service.

    ```
    $ vagrant up
    ```


 Now, `github_bot` runs inside the pool service container as a github integration service. After you create pull request on target repository, `github_bot` comments preview url on the pull requst.

 Image below:

![](https://dl.dropboxusercontent.com/u/10177896/pool_github_integration.png)


Stop/start the `github_bot` service
--------------------------------------

`github_bot` service is daemonized by supervisord, so if you want to stop the bot service, enter the container and type the command `supervisorctl stop github_bot`.


    $ vagrant ssh
    $ sudo docker exec -it pool
    $ supervisorctl stop github_bot
