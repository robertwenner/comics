# Developer documentation

The code centers around the [Comic](../lib/Comic.pm) module. Each Comic
instance represents one comic read from an Inkscape `.svg` file. The Comic
module makes the comic's metadata available. It acts as a collecting
parameter when passed to the output generating modules, as these may need to
store e.g., the path to the file they generated somewhere so that the
templates can access that file.

The [Comics](../lib/Comics.pm) (plural, not my greatest naming choice)
module controls how comics get processed:

- it loads the configuration
- it collects all input Inkscape files
- it runs all configured checks on the loaded `Comic`s
- it passes the `Comic`s to the configured output generators
- it uploads the generated files to your web server
- it posts the latest comic to the configured social media outlets

To extend this, you can add new checks, output generators, or social media
posters.


## Checks

Check modules look at each `Comic` and flag problems like typos. To add a
new check, derive from the [Checks](../lib/Comic/Check/Check.pm) module
and implement the `check` method, and maybe `notify` as needed. See the POD
in that module for details.

The `Comics` module collects checks by their class name, so the new module
name must start with `Comic::Check::...`


## Output generators

Output generating modules take each `Comic` and produce output like an HTML
page or an archive overview page. To add a new output generator, derive from
the [Generator](../lib/Comic/Out/Generator.pm) base module and implement the
`generate` or `generate_all` methods as needed. See the POD for details.

If your generator depends on the output of another generator, you must
insert it in the correct position in the generators list. This is hard-coded
in the `Generator` module's `order` function.

Each generator should write to the passed `Comic`, so that other generators
and templates can access the generator's information. For example, the HTML
page template needs to know the name of the comic image file in each
language, so the image exporter puts that name into the `Comic`. This
requires syncing templates and generators (and generators with each other),
so we need decent end user documentation on the variables each generator
defines.

The `Comics` module collects output generators by their class name, so the
new module name must start with `Comic::Out::...`


## Uploaders

Uploader modules upload the generated content somewhere, e.g., to your web
server. To add a new uploader, derive from the
[Uploader](../lib/Comic/Upload/Uploader.pm) module and implement the
`upload` method. See the POD for details.

The `Comics` module collects output generators by their class name, so the
new module name must start with `Comic::Upload::...`


## Social media posters

Social media modules post the latest comic to the social media platforms.
To add a new social media poster, derive from the
[Social](../lib/Comic/Social/Social.pm) module and override the `post`
method. Note that some social networks may not be worth directly supporting
if there is an easier way to post, like [Zapier](https://zapier.com).
Writing a specialized module has the advantage that you can fine-tune how
you post the comics and what metadata you include.

The `Comics` module collects output generators by their class name, so the
new module name must start with `Comic::Social::...`
