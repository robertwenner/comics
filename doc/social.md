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


## `Comic::Social::Mastodon`

To have the `Comic::Social::Mastodon` module toot for you, you must
configure your Mastodon account. This is a one time setup. Log in to your
Mastodon account, then go to development and click [New
Application](https://mstdn.io/settings/applications/new) at the top right.

* enter any name, like "comic updater"

* enter any website (or use [https://github.com/robertwenner/comics](https://github.com/robertwenner/comics))

* check the `write:media` and `write:statuses` permissions

* save the page, then click your new app in the app list to reveal the details

* from that details page, copy client key, client secret, and access token
  to your configuration file

You can enable two-factor authentication in Mastodon and this code can still
toot for you.

Configure your comic settings like this:

```json
{
    "Social": {
        "Comics::Social::Mastodon": {
            "client_key": "from the Mastodon app page",
            "client_secret": "from the Mastodon app page",
            "access_token": "from the Mastodon app page",
            "instance": "mastodon.social",
            "mode": "png"
        }
    }
}
```

The instance is the mastodon server where you have your account. If you don't
specify an instance, it will probably be `mastodon.social`, which is what
[Mastodon::Client](https://metacpan.org/pod/Mastodon::Client) uses by
default.

The `Comic::Check::Mastodon` module adds any hashtags from `hashtags` and
`mastodon` (in that order) from the Comic's metadata to the posted message.
Use the `hashtags` for general hashtags and `mastodon` for Mastodon-specific ones
like mentions.

```json
{
    "hashtags": {
        "English": ["#beer"],
        "Deutsch": ["#Bier"]
    },
    "mastodon": {
        "English": ["@you"],
        "Deutsch": ["@other@instance"]
    }
}
```

If `mode` is png, the tooted message is the comic's title, its description,
and the given twitter hashtags, plus the actual comic `png` file; separated by
newlines. If the mode is `html`, the comic's page URL is added to the
message as well.


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
    "Social": {
        "Comic::Social::Reddit": {
            "username": "your reddit name",
            "password": "secret",
            "client_id": "...",
            "secret": "...",
            "default_subreddit": "comics",
            "title_prefix": "[OC] ",
            "title_suffix": " [OC]",
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

* `title_prefix` is a placed in front of the comic's title when posting. It
  defaults to nothing (i.e., nothing will be inserted in front of the
  title). You can place e.g., `[OC]` in there to indicate original content.
  Make sure to include a space after the prefix text so that the prefix is
  not glued right onto the title.

* `title_suffix` is like `title_prefix`, except that it goes after the comic's
  title. Start the suffix text with a space if you use it.


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
the tweet will be made from the comic's title, description, and the hashtags
and twitter meta data (i.e., hashtags). Twitter hashtags can be passed in
the Comic's `hashtags -> language` and `twitter -> language` arrays, where
`hashtags` will be used for other social media networks that use hashtags
(like Mastodon) as well and `twitter` hashtags are only used for Twitter.
Use the former for general purpose hashtags, and the latter for network
specific ones like mentions.

If the combined text is too long, it will be truncated.

For example, if the given Comic has this meta data:

```json
{
    "title": {
        "english": "Brewing my own beer!",
        "deutsch": "Ich braue mein eigenes Bier!"
    },
    "description": {
        "english": "Because I can!",
        "deutsch": "Weil ich's kann!"
    },
    "hashtags": {
        "#homebrewing"
    },
    "twitter": {
        "english": [ "@brewery" ],
        "deutsch": [ "@person" ]
    }
}
```

This will be tweeted in English as "Brewing my own beer! Because I
can! #homebrewing @brewery" and in German as "Ich braue mein eigenes
Bier! Weil ich's kann! #homebrewing @person".
