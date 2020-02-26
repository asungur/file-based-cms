# File-based Content Management System

A simple file-based content management system. Allows logged in users to create/edit/delete files. Guest visitors can only view the files

## Original features

* Index page
* Viewing `.txt` and `.md` files
* Handling requests for non-existent documents
* Editing document content (restricted)
* Creating new documents (restricted)
* Deleting documents (restricted)
* User sign-in/out

## Added features (*in progress*)

* ✅ Validate that document names contain an extension that the application supports. 
  * Filenames can not be created without an extension
  * `.txt` and `.md` are only accepted file formats
  * Filenames can not contain special characters `/\:*?<>|`
* ✅ Add a "duplicate" button that creates a new document based on an old one.
* ✅ Extend this project with a user signup form.
* ✅ Add the ability to upload images to the CMS (which could be referenced within markdown files).
* ✅ Modify the CMS so that each version of a document is preserved as changes are made to it.

## Running in your own machine

Clone the project and :

1. Remove the `Gemfile.lock`
2. `bundle exec install` downloads and install the required gems
3. Run the app via bundler `bundle exec ruby cms.rb`
4. For the test suite, run the command from the project folder: `bundle exec ruby ./test/cms_test.rb` 

*P.S: It is recommended to use ruby 2.6.X*

## Development

* Writing tests with Rack::Test and Sinatra
* Isolating test execution via `ENV["RACK_ENV"]`
* CSS Body and Message styling
* `favicon.ico`
* Stored user account credentials in an external file.
* Hashed passwords via `BCrypt`

## Further development

* Delete history files upon file deletion.
* Add user interface.

## Credits

This project is *being* implemented on the base code from the File-based CMS project from Launch
School's Web Development course (#170).
