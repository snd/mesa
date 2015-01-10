{setup, teardown, mesa} = require './src/common'

{Person} = require('../example/active-record')(mesa)

module.exports =

  'setUp': setup
  'tearDown': teardown

  'instance lifecycle': (test) ->
    person = new Person
      name: 'Jake Gyllenhaal'

    person.save()
      .then ->
        test.ok person.id?
        test.done()
