# Sidekiq Extensions

[![Build Status](https://secure.travis-ci.org/freewrite/sidekiq_extensions.png)](http://travis-ci.org/freewrite/sidekiq_extensions)
[![Dependency Status](https://gemnasium.com/freewrite/sidekiq_extensions.png)](https://gemnasium.com/freewrite/sidekiq_extensions)
[![Coverage Status](https://coveralls.io/repos/freewrite/sidekiq_extensions/badge.png?branch=master)](https://coveralls.io/r/freewrite/sidekiq_extensions)
[![Code Climate](https://codeclimate.com/github/freewrite/sidekiq_extensions.png)](https://codeclimate.com/github/freewrite/sidekiq_extensions)

Modular extensions for Sidekiq message processor including modules to enable host-specific queues; hybridized queuing strategies leveraging both prioritized queues and weighted queues; and per-job limiting by process, host, queue, or Redis instance.
