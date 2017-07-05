About
=====

Example daemon that polls Varnish every 60 seconds and logs the change
in its counters to AWS CloudWatch.


Dependencies
============
* ISE Eiffel.
* eposix.
* jrs.


Installation
============

Expects AWS settings in ~/.aws/config and credentials in ~/.aws/credentials.

Use the supplied varnish_to_cloudwatch.service to run the daemon under
systemd.
