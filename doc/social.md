# Social media network modules

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

The order in which these modules run is undefined, but they will only run
after all [Upload](upload.md) modules have finished.


## `Comic::Social::Email`

Emails the current comic to a list of recipients, per language.

This is a somewhat basic implementation (new connection per recipient), and
probably not too efficient. It may work for a few emails, but your email
provider may enforce sending limits. If you use want to email more than a
handful of people, you should look into proper list management tools that
cover subscribes and unsubscribes as well as sending bulk emails.

To email the latest comic, configure it like this:

```json
    "Social": {
        "Comic::Social::Email": {
            "server": "smtp.gmail.com",
            "sender_address": "Me <me@example.org>",
            "password": "super secret",
            "mode": "png",
            "recipient_list": {
                "English": "recipients.english"
            }
        }
    }

```

The `server` is the sending email server. You can use your email provider's
server and fill in the details as needed.

`sender_address` is your own email address, like `me@example.org`.

The `password` is the password you use to log in to your email account.

The `mode` specifies whether to send a link to the comic (mode `html`) or
the `png` image of the comic as an attachment to the email.

The `recipient_list` specifies a file per language. That file must have each
recipient email on a single line.

When `Comic::Social::Email` sends an email, it will:

* make an encrypted connection to your server

* use the comic's title as the subject of the email

* use the comic's description as the body of the email


## `Comic::Social::IndexNow`

Asks search engines that support the [index now](https://indexnow.org)
standard to index the new comic page.

To use this, you must first create a key, put that key into a file named
like the key with a `.txt` extension, and put that file in your website's
root directory.

On Linux, you can use the `uuidgen` tool to create a key:

```bash
export key=$(uuidgen)
echo $key > web/all/$key.txt
```

If you don't have that tool, just come up with some random numbers and
letters (at least 8 characters), for example "test1234". Put "test1234" in a
file named `test1234.txt` in your server.

Then configure this module:

```json
    "Social": {
        "Comic::Social::IndexNow": {
            "key": "your key from above",
            "url": "https://indexnow.org/indexnow"
        }
    }
```

The `key` is your somewhat secret made up key. You must use the same key for
all languages / domains.

The optional `url` is the URL that this module will tell about your new
comic. If not given, it defaults to `https://api.indexnow.org/indexnow`.


## `Comic::Social::Mastodon`

To have the `Comic::Social::Mastodon` module toot for you, you must
configure your Mastodon account. This is a one time setup. Log in to your
Mastodon account, then go to development in the left hand menu and click [New
Application](https://mstdn.io/settings/applications/new) at the top right.

* enter any name, like "comic updater"

* enter any website (or use [https://github.com/robertwenner/comics](https://github.com/robertwenner/comics))

* check the `write:media` and `write:statuses` permissions; everything else
  can be unchecked

* save the page, then click your new app in the app list to reveal the details

* from that details page, copy the access token to your configuration file as
  described below

This module should work with Mastodon servers version 3.1.3 or later.

Configure your comic settings like this:

```json
{
    "Social": {
        "Comics::Social::Mastodon": {
            "access_token": "from the Mastodon app page",
            "instance": "mastodon.social",
            "mode": "png",
            "visibility": "public"
        }
    }
}
```

The instance is the mastodon server where you have your account, e.g.,
`mstdn.io`. Don't include e.g., `https://` or a path after the name.

The `visibility` is optional. If not given, it defaults to the visibility in
your account settings. You can override the visibility here for testing.

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
and the hashtags from the comic (separated by newlines); plus the actual
comic `png` file. If the mode is `html`, the comic's page URL is added to
the message as well, but the image is not included.

All posts will use your account's default visibility, e.g., "public".

You can enable two-factor authentication in Mastodon and this code can still
toot for you.


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
