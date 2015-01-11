_ = require 'lodash'

{setup, teardown, mesa} = require './src/common'

movieTable = mesa.table('movie')
personTable = mesa.table('person')
starringTable = mesa.table('starring')

idWhereName = (array, name) ->
  _.find(array, {name: name}).id

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
                director_id: personId('Michael Mann')
                writer_id: personId('Michael Mann')
              }
              {
                name: 'True Romance'
                director_id: personId('Tony Scott')
                writer_id: personId('Quentin Tarantino')
              }
              {
                name: 'Easy Rider'
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

    'belongsTo': (test) ->
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

    'hasMany': (test) ->
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
          test.equal people[0].written.length, 1
          test.equal people[0].written[0].name, 'Easy Rider'
          test.equal people[0].directed.length, 1
          test.equal people[0].directed[0].name, 'Easy Rider'

          test.equal people[2].name, 'Michael Mann'
          test.equal people[2].written.length, 1
          test.equal people[2].written[0].name, 'Heat'
          test.equal people[2].directed.length, 1
          test.equal people[2].directed[0].name, 'Heat'

          test.equal people[3].name, 'Tony Scott'
          test.equal people[3].directed.length, 1
          test.equal people[3].directed[0].name, 'True Romance'
          test.equal people[3].written.length, 0

          test.equal people[4].name, 'Quentin Tarantino'
          test.equal people[4].written.length, 1
          test.equal people[4].written[0].name, 'True Romance'
          test.equal people[4].directed.length, 0

          test.done()

# #   'hasOneThrough': (test) ->
# #     test.done()
# #
# #   'hasManyThrough': (test) ->
# #     movieTable
# #       .queueEmbedHasMany(
# #         table: personTable
# #         through: performanceTable
# #         as: 'actors'
# #       )
# #       .find()
# #     personTable
# #       .queueEmbedHasMany(movieTable, performanceTable,
# #         as: 'starredIn'
# #       )
#       TODO the directors an actor had to do with
# #       .find()
# #     test.done()
#
#   'hasOne fetch with join': (test) ->
#     test.done()
#
#   'belongsTo fetch with join': (test) ->
#     test.done()
#
#   'nested': (test) ->
#     test.done()
#
#   'from subquery': (test) ->
#     # TODO directory and writer
#     test.done()
