# Introduction

This plugin allows the MARC stage step to allow importing MARC records from CSV files.

# Adding the plugin to Koha

## Download the plugin installer

In order to install this plugin, you need to download the _.kpz_ file from the [release page](https://github.com/bywatersolutions/koha-plugin-csv2marc/releases).

## Enable the plugin system

The plugin system needs to be turned on by a system administrator.

To set up the Koha plugin system you must first make some changes to your install.

* Change `<enable_plugins>0<enable_plugins>` to `<enable_plugins>1</enable_plugins>` in your koha-conf.xml file
* Confirm that the path to `<pluginsdir>` exists, is correct, and is writable by the web server
* Restart Koha:

```
  $ sudo service koha-common restart
```

Once set up is complete you will need to alter your UseKohaPlugins system preference.

## Install

In _Home > Administration > Manage plugins_ you will find the option to upload the downloaded _.kpz_ file.

## Upgrade

If you want to install a newer version of the plugin, just repeat the install step with the newer _.kpz_ file.

# Usage

On the plugin configuration page, you will find a form in which you need to add your mappings before using the plugin.

Add a line for each tag you'd like to create. In that tag you can have multiple subfields that should be created and the column index to be used.
NOTE: Columns indexes begin at 0.

Repeatable fields require the use of underscore on the tag number as shown in this example configuration. Notice the example makes 650 fields be created reusing the column for indicators and source. Remember to add _required: true_ the not-reused subfield (the main heading in the example). This is needed to prevent creating fields if the main subfield is not present on the spreadsheet.

Control fields are supported! It is recommended that you put a default value for the control field in a column (configured as position 0), and then define the positions mappings. See _000_ in the example below.

## Example

```
000:
  - column: 0
    position: 0
  - column: 1
    position: 7
  - column: 2
    position: 15
003:
  - column: 3
008:
  - column: 4
    position: 6
  - column: 5
    position: 7
  - column: 6
    position: 15
  - column: 7
    position: 35
100:
  - subfield: a
    column: 8
245:
  - indicator: 1
    column: 9
  - indicator: 2
    column: 10
  - subfield: a
    column: 11
650_1:
  - indicator: 2
    column: 12
  - subfield: 2
    column: 13
  - subfield: a
    column: 14
    required: true
650_2:
  - indicator: 2
    column: 12
  - subfield: 2
    column: 15
  - subfield: a
    column: 16
    required: true
```
