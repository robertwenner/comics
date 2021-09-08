# Social networks

The `Comic::Social::...` modules post the latest comic for each language on
social networks.

If you have multiple latest comics, e.g., one only in English and one only
in German, the social media code will post both.

Some social networks are a pain in the lower end of the back, in particular
Facebook. (I hate Facebook, for various reasons, and this did not help.)
Because of that only easy social network are supported. For everything
else, create a [RSS Feed](outputs.md#Comic::Out::Feed) and hook it up to a
free [Zapier](https://zapier.com) account to spread the joy elsewhere.


## `Comic::Social::Reddit`

Posts the current comic to [reddit.com](https://reddit.com).

Before this module can post for you to Reddit, you need to go to your [Reddit
apps settings](https://www.reddit.com/prefs/apps), then create an app
(script). This will get you the secret needed to configure this module.

Unfortunately you cannot use Reddit's two factor authentication or the
script won't be able to log in.

The configuration looks like this:

```json
{
    "Social":
        "Reddit": {
            "username": "your reddit name",
            "password": "secret",
            "client_id": "...",
            "secret": "...",
            "default_subreddit": "comics"
        }
    }
}
```

These values are:

* `username`: your Reddit user name.

* `password`: your Reddit password.

* `client_id`: from your Reddit account's apps details page.

* `secret`: from your Reddit account's apps details page.

* B<$default_subreddit> Optional default subreddit(s), e.g., "funny" or
  "/r/comics". This is language-independent. If there is no default
  subreddit and the comic doesn't specify subreddits either, it won't be
  posted to Reddit at all.
