{setup, teardown, mesa} = require './src/common'

# insertMovieData = ->
#   movieTable = mesa.table('movie')
#   personTable = mesa.table('movie')
#   performanceTable = mesa.table('performance')
#   directionTable = mesa.table('direction')
#   productionTable = mesa.table('production')
#
#   actors = [
#     'Robert De Niro'
#   ]
#
#   movies = [
#     {name: 'Heat'}
#     {name: 'Brazil'}
#     {name: 'Interstellar'}
#   ]
#
#   movieTable
#     .unsafe()
#     .insert(movies)

module.exports =

  'setUp': setup
  'tearDown': teardown

  'hasOne': (test) ->
    test.done()

#   'hasMany': (test) ->
#     personTable
#       .queueEmbedHasMany(movieTable, {fk: 'director_id'})
#     test.done()
#
#   'belongsTo': (test) ->
#     movieTable
#       .queueEmbedBelongsTo(personTable, {fk: 'director_id'})
#     test.done()
#
#   'hasOneThrough': (test) ->
#     test.done()
#
#   'hasManyThrough': (test) ->
#     movieTable
#       .queueEmbedHasMany(
#         table: personTable
#         through: performanceTable
#         as: 'actors'
#       )
#       .find()
#     personTable
#       .queueEmbedHasMany(movieTable, performanceTable,
#         as: 'starredIn'
#       )
#       .find()
#     test.done()

  'hasOne fetch with join': (test) ->
    test.done()

  'belongsTo fetch with join': (test) ->
    test.done()
