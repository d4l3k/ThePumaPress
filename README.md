The Puma Press [![Stories in Ready](https://badge.waffle.io/d4l3k/ThePumaPress.png?label=ready)](https://waffle.io/d4l3k/ThePumaPress)  
============

This is the new website for The Puma Press -- University Prep's Student Newspaper.

Setup
----
The Puma Press requires a database server of some sort. I use PostgreSQL, but you can use anything that's compatible with DataMapper. You can configure it on the 4th line of `main.rb`.

Clone the repository:
```shell
git clone https://github.com/d4l3k/ThePumaPress.git
```

Run bundler:
```shell
bundle
```
Precompile the website assets:
```shell
rake assets:precompile
```
Configure Thin in thin.yaml then launch it:
```shell
thin start -C thin.yaml
```

License
----
Copyright (c) 2013 Tristan Rice

ThePumaPress website is licensed under the [MIT License](http://opensource.org/licenses/MIT).
