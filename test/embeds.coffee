_ = require 'lodash'

{setup, teardown, mesa} = require './src/common'

# mesa = mesa.debug((args...) -> console.log args[...3]...)

movieTable = mesa.table('movie')
personTable = mesa.table('person')
starringTable = mesa.table('starring')

idWhereName = (array, name) ->
  _.find(array, {name: name}).id

names = (array) ->
  _.pluck array, 'name'

module.exports =
  'unit':

    'defaultsForEmbed':

      'full options are passed through and cloned': (test) ->
        options =
          thisKey: 'user_id'
          otherKey: 'id'
          thisIsForeign: true
          many: true
          as: 'comments'
        optionsWithDefaults = mesa.defaultsForEmbed mesa, options
        test.ok not (options is optionsWithDefaults)
        test.deepEqual options, optionsWithDefaults

        test.done()

    'has one': (test) ->
        options =
          thisKey: 'id'
          otherKey: 'user_id'
          thisIsForeign: false
          many: false
          as: 'profile'
        userTable = mesa.table('user')
        profileTable = mesa.table('profile')
        test.deepEqual options, userTable.defaultsForEmbed profileTable
        test.done()

    'has one with custom primary keys': (test) ->
        options =
          thisKey: 'uid'
          otherKey: 'user_uid'
          thisIsForeign: false
          many: false
          as: 'profile'
        userTable = mesa.table('user').primaryKey 'uid'
        profileTable = mesa.table('profile').primaryKey 'pid'
        test.deepEqual options, userTable.defaultsForEmbed profileTable
        test.done()

    'has many': (test) ->
        options =
          thisKey: 'id'
          otherKey: 'user_id'
          thisIsForeign: false
          many: true
          as: 'profiles'
        userTable = mesa.table('user')
        profileTable = mesa.table('profile')
        test.deepEqual options, userTable.defaultsForEmbed profileTable,
          many: true
        test.done()

    'belongs to': (test) ->
        options =
          thisKey: 'profile_id'
          otherKey: 'id'
          thisIsForeign: true
          many: false
          as: 'profile'
        userTable = mesa.table('user')
        profileTable = mesa.table('profile')
        test.deepEqual options, userTable.defaultsForEmbed profileTable,
          thisIsForeign: true
        test.done()

  'integration':

    'setUp': (done) ->
      setup().then ->

        people = [
          {name: 'Dennis Hopper'}
          {name: 'Keanu Reeves'}
          {name: 'Michael Mann'}
          {name: 'Tony Scott'}
          {name: 'Quentin Tarantino'}
          {name: 'Robert De Niro'}
          {name: 'Al Pacino'}
          {name: 'Val Kilmer'}
        ]

        personTable
          .unsafe()
          .insert(people)
          .then (insertedPeople) ->
            personId = idWhereName.bind(null, insertedPeople)

            movies = [
              {
                name: 'Heat'
                year: 1995
                director_id: personId('Michael Mann')
                writer_id: personId('Michael Mann')
              }
              {
                name: 'True Romance'
                year: 1993
                director_id: personId('Tony Scott')
                writer_id: personId('Quentin Tarantino')
              }
              {
                name: 'Easy Rider'
                year: 1969
                director_id: personId('Dennis Hopper')
                writer_id: personId('Dennis Hopper')
              }
              # {name: 'Brazil'}
              # {name: 'Interstellar'}
            ]

            movieTable
              .unsafe()
              .insert(movies)
              .then (insertedMovies) ->
                movieId = idWhereName.bind(null, insertedMovies)

                starring = [
                  {
                    movie_id: movieId('Heat')
                    person_id: personId('Robert De Niro')
                  }
                  {
                    movie_id: movieId('Heat')
                    person_id: personId('Al Pacino')
                  }
                  {
                    movie_id: movieId('Heat')
                    person_id: personId('Val Kilmer')
                  }
                  {
                    movie_id: movieId('True Romance')
                    person_id: personId('Val Kilmer')
                  }
                  {
                    movie_id: movieId('True Romance')
                    person_id: personId('Dennis Hopper')
                  }
                  {
                    movie_id: movieId('Easy Rider')
                    person_id: personId('Dennis Hopper')
                  }
                ]

                starringTable
                  .unsafe()
                  .insert(starring)
                  .then ->
                    done()

    'tearDown': teardown

    'belongsTo: embed director in movie': (test) ->
      movieTable
        .queueEmbedBelongsTo(personTable,
          thisKey: 'director_id'
          otherKey: 'id'
          as: 'director'
        )
        .find()
        .then (movies) ->
          test.equal movies[0].name, 'Heat'
          test.equal movies[0].director.name, 'Michael Mann'
          test.equal movies[1].name, 'True Romance'
          test.equal movies[1].director.name, 'Tony Scott'
          test.equal movies[2].name, 'Easy Rider'
          test.equal movies[2].director.name, 'Dennis Hopper'
          test.done()

    'hasMany: embed written and directed movies in person': (test) ->
      personTable
        .queueEmbedHasMany(movieTable,
          otherKey: 'writer_id'
          as: 'written'
        )
        .queueEmbedHasMany(movieTable,
          otherKey: 'director_id'
          as: 'directed'
        )
        .find()
        .then (people) ->
          test.equal people[0].name, 'Dennis Hopper'
          test.deepEqual names(people[0].written), ['Easy Rider']
          test.deepEqual names(people[0].directed), ['Easy Rider']

          test.equal people[2].name, 'Michael Mann'
          test.deepEqual names(people[2].written), ['Heat']
          test.deepEqual names(people[2].directed), ['Heat']

          test.equal people[3].name, 'Tony Scott'
          test.deepEqual names(people[3].written), []
          test.deepEqual names(people[3].directed), ['True Romance']

          test.equal people[4].name, 'Quentin Tarantino'
          test.deepEqual names(people[4].written), ['True Romance']
          test.deepEqual names(people[4].directed), []

          test.done()

    # TODO make this firstWritten
    # order movies by year
    'hasOne: just return the first': (test) ->
      personTable
        .queueEmbedHasOne(movieTable.order('year ASC'),
          otherKey: 'writer_id'
          as: 'firstWritten'
        )
        .queueEmbedHasOne(movieTable.order('year ASC'),
          otherKey: 'director_id'
          as: 'firstDirected'
        )
        .find()
        .then (people) ->
          test.equal people[0].name, 'Dennis Hopper'
          test.equal people[0].firstWritten.name, 'Easy Rider'
          test.equal people[0].firstDirected.name, 'Easy Rider'

          test.equal people[2].name, 'Michael Mann'
          test.equal people[2].firstWritten.name, 'Heat'
          test.equal people[2].firstDirected.name, 'Heat'

          test.equal people[3].name, 'Tony Scott'
          test.ok not people[3].firstWritten?
          test.equal people[3].firstDirected.name, 'True Romance'

          test.equal people[4].name, 'Quentin Tarantino'
          test.equal people[4].firstWritten.name, 'True Romance'
          test.ok not people[4].firstDirected?

          test.done()

    'has many through: movies an actor has starred in': (test) ->
      starringTableWithMovie = starringTable
        .queueEmbedBelongsTo(movieTable)
      personTable
        .queueEmbedHasMany(starringTableWithMovie)
        .queueAfterEach ((record) ->
          record.movies = _.pluck record.starrings, 'movie'
          delete record.starrings
          return record
        )
        .find()
        .then (people) ->
          test.equal people[0].name, 'Dennis Hopper'
          test.deepEqual names(people[0].movies), ['True Romance', 'Easy Rider']
          test.equal people[1].name, 'Keanu Reeves'
          test.deepEqual names(people[1].movies), []
          test.equal people[2].name, 'Michael Mann'
          test.deepEqual names(people[2].movies), []
          test.equal people[3].name, 'Tony Scott'
          test.deepEqual names(people[3].movies), []
          test.equal people[4].name, 'Quentin Tarantino'
          test.deepEqual names(people[4].movies), []
          test.equal people[5].name, 'Robert De Niro'
          test.deepEqual names(people[5].movies), ['Heat']
          test.equal people[6].name, 'Al Pacino'
          test.deepEqual names(people[6].movies), ['Heat']
          test.equal people[7].name, 'Val Kilmer'
          test.deepEqual names(people[7].movies), ['Heat', 'True Romance']

          test.done()

#   TODO the directors an actor had to do with
#
#   'nested': (test) ->
#     test.done()
#
#   'hasOne fetch with join': (test) ->
#     test.done()
#
#   'belongsTo fetch with join': (test) ->
#     test.done()
#
#   'from subquery': (test) ->
#     # TODO directory and writer
#     test.done()
