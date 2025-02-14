# Activefacts::Fig

A FIG (Fact Interchange Grammar) language implementation for ActiveFacts

## About

FIG is a concrete syntax for Object Role Models (ORM) representing an ORM Conceptual Model,
as defined in the ORM Syntax and Semantics https://github.com/cjheath/orm-syntax-and-semantics-docs

This parser does not yet populate an ActiveFacts model, it just emits the parse tree for each input definition.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activefacts-fig'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activefacts-fig

## Usage

    $ schema_compositor --options input_file.fig

## Development

After checking out the repo, run `rake build`. Then, run `rake rspec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## See Also

https://gitlab.com/orm-syntax-and-semantics/orm-syntax-and-semantics-docs
https://gitlab.com/orm-syntax-and-semantics/orm-syntax-and-semantics-docs/-/tree/master

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/cjheath/activefacts-fig.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

