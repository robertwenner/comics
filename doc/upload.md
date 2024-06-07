# Uploading comics

The upload modules allow uploading to servers. They are included with the
other comic modules as a convenient way of generating, checking, and
uploading the comics --- all in one place, when used from Comics'
convenience functions, without extra scripting.

The order in which these modules run is undefined, but they will only run
after all [Output](outputs.md) modules have finished.


## `Comic::Upload::Rsync`

Uses `rsync` (which needs to be installed) to copy files, e.g., to a web
server. You will also need to have your server configured to accept either
`rsync` or (better) secure shell (`ssh`) connections.

This needs to be configured for any site to which you want to `rsync`:

```json
{
    "Upload": {
        "Comic::Upload::Rsync": {
            "sites": {
                "deutsch": {
                    "source": "generated/web/deutsch",
                    "destination": "you@your-server.example.com:deutsch/"
                },
                "english": {
                    "source": "generated/web/english",
                    "destination": "you@your-server.example.com:english/"
                }
            },
            "keyfile": ".ssh/mykey.id_rsa",
            "options": [
                "update",
                "checksum"
            ]
        }
    }
}
```

* `sites` is a list of sites to which you want to copy files. Each item in
  the sites list needs to be an object with a source and destination. The
  source is a path (can be relative to the directory where you run the
  Comic modules), the destination is the remote server plus path.

* `keyfile` is an optional parameter to specify the ssh key file. If you run
  this automated in a `cron` job, the key should not have a pass phrase as
  there won't be anybody to punch it in.

* `options` is an optional list of `rsync` options that take no arguments.

  Note that you can only use options that don't take any arguments.
  `--update` is fine, but `--exclude` is not, as the latter expects a file
  pattern. (If you place all output in a directory tree per language you
  shouldn't need to exclude anything anyway.)

  The [`File::Rsync`](https://metacpan.org/pod/File::Rsync) module's
  documentation states that you can pass the options in different forms:
  "Options ... are the same as the long options in `rsync`(1) without the
  leading double-hyphen. Any leading single or double-hyphens are removed,
  and you may use underscore in place of hyphens". For example, the command
  line option `--update` could be written as just `update`. See the [`rsync`
  manual](https://linux.die.net/man/1/rsync) for the available options.

  If no `options` are given, they default to `update` (only send modified
  files), `checksum` (use file checksum vs modification time to check if
  files have changed), `compress` (compress files for better performance
  during transfer), `recursive` (send the whole directory tree), `delete`
  (delete files on the server that have been deleted locally), and `times`
  (preserve file modification times).

* `check` (optional): an object with `tries` and `delay`: if given, try to
  get the latest comics' URLs in each language from the web server. If that
  fails, wait `delay` seconds and try again, up to `tries` times. If the web
  server still doesn't return something for the URL, assume uploading failed
  and exit with an error. This is meant to prevent later modules from
  posting dead links to social media when a sluggish web server hasn't yet
  made the new comic available. If `check` is not given, there won't be any
  checks whether the web server is ready.

The above example configuration would upload all German comics from
`generated/web/deutsch/` and all English comics from
`generated/web/english` to the server `your-server.example.com` (logging in
as `you` with the `ssh` key in `.ssh/mykey.id_rsa`) to the `deutsch/` and
`english/` directories respectively. It would use the `--update` and
`--checksums` `rsync` options.

Consider the following example for retrying:

```json
{
    "Upload": {
        "Comic::Upload::Rsync": {
            "check": [
                "tries": 30,
                "delay": 10
            ]
        }
    }
}
```

The above example will try to load the Comic's URLs up to 30 times, with a
delay of 10 seconds between tries, for up to 5 minutes, exiting with an
error if the URL is not available by then. As soon as the web server
delivers the page, the check exits successfully.
