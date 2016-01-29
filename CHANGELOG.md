# Changelog

## 1.1.0 (2016-01-29)
### Fixes
  - Handle new ruby lambda backtrace syntax
  - Don't treat nested errors separately

## 1.0.3 (2016-01-26)
### Fixes
  - Fix syntax error

## 1.0.2 (2016-01-26)
### Fixes
  - Wrong status code for response

## 1.0.1 (2016-01-25)
### Fixes
  - Add space to comma separated key-value list in description tables
  - Exclude notifier information from context table

## 1.0.0 (2016-01-23)
### Changes
  - Add support for new v3 JSON notices
  - Add support for new v3 JSON iOS reports
  - Dropped support for old notices and reports APIs
  - Add permission to use Airbrake API. No longer bound to issue create permission
  - Added new key *column* in backtrace to ID calculation
  - Require Redmine >= 3.2.0
  - Show hashes in table sections (no recursion)

## 0.6.1 (2015-04-28)
### Fixes
  - Usage as Redmine plugin additional to gem

## 0.6.0 (2015-04-22)
### Changed
  - Redmine 3.0.x compatibility
  - Switched from hpricot to nokogiri for XML parsing
