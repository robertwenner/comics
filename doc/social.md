# Social media networks

The `Comic::Social::...` modules post today's comic for each language on
social networks.

If you have multiple comics for today, for example, one only in English and
one only in German, the social media code will post both.

Some social networks are more painful to automate than others, in particular
Facebook. (I hate Facebook, for various reasons, and their finicky API did
not help.) Because of that only easy social networks are supported. For
everything else, create a [RSS Feed](outputs.md#Comic::Out::Feed) and hook
it up to a free [Zapier](https://zapier.com) account to spread the joy.

All `Comic::Social::...` configuration must be within the `Social` object.


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
        "Comic::Social::Reddit":
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

* `username`: your Reddit username.

* `password`: your Reddit password.

* `client_id`: from your Reddit account's apps details page.

* `secret`: from your Reddit account's apps details page.

* `default_subreddit` Optional default subreddit(s), e.g., "funny" or
  "/r/comics". This is language-independent. If there is no default
  subreddit and the comic doesn't specify subreddits either, it won't be
  posted to Reddit at all.


## `Comic::Social::Twitter`

Tweets a comic.

Before this module can tweet for you, you need to go to your Twitter [app
settings](https://developer.twitter.com/apps/) and allow it to post on your
behalf. This will get you the credentials you need below.

The configuration looks like this:

```json
{
    "Social": {
        "Comic::Social::Twitter": {
            "mode": "png",
            "consumer_key": "...",
            "consumer_secret": "...",
            "access_token": "...",
            "access_token_secret": "..."
        }
    }
}
```

The fields are:

* `mode`: either `html` or `png` to tweet either a link to the comic or
  the actual comic `png` file. Defaults to `png`. `html` mode requires that the
  comic is uploaded and the URL is available in the Comic. `png` mode
  requires that the `.png` has been generated and its filename is stored in
  the Comic.

* `consumer_key` from your Twitter app settings.

* `consumer_secret` from your Twitter app settings.

* `access_token` from your Twitter app settings.

* `access_token_secret` from your Twitter app settings.

Tweeting the comic means to tweet it in each of its languages. The text for
the tweet will be made from the comic's title, description, and twitter meta
data (i.e., hashtags). Twitter hashtags can be passed in the Comic's
`twitter -> language` array. If the combined text is too long, it will be
truncated.

For example, if the given Comic has this meta data:

```
{
    "title": {
        "english": "Brewing my own beer!",
        "deutsch": "Ich braue mein eigenes Bier!"
    },
    "description": {
        "english": "Because I can!",
        "deutsch": "Weil ich's kann!"
    },
    "twitter": {
        "english": [ "#beer", "#brewing" ],
        "deutsch": [ "#Bier", "#brauen" ]
    }
}
```

This will be tweeted in English as "Brewing my own beer! Because I can! #beer #brewing"
and in German as "Ich braue mein eigenes Bier! Weil ich's kann! #Bier #brauen".
