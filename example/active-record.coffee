_ = require 'lodash'

# camelToSnake('camelCase') returns 'camel_case'
camelToSnake = (string) ->
  string.replace /([a-z][A-Z])/g, (m) -> m[0] + '_' + m[1].toLowerCase()

# snakeToCamel('snake_case') returns 'snakeCase'
snakeToCamel = (string) ->
  string.replace /_([a-z])/g, (m) -> m[1].toUpperCase()

mapKeys = (object, f) ->
  result = {}
  Object.keys(object).forEach (key) ->
    result[f key] = object[key]
  return result

snakeToCamelObject = (snake) -> mapKeys snake, snakeToCamel
camelToSnakeObject = (camel) -> mapKeys camel, camelToSnake

################################################################################
# record

# constructor
Record = (data) ->
  _.assign(@, data)

# instance methods
Record.prototype =
  save: ->
    that = @
    if @id?
      @_table
        .where(id: @id)
        .returnFirst()
        .update(@)
        .then (data) ->
          _.assign that, data
          return that
    else
      @_table
        .insert(@)
        .then (data) ->
          _.assign that, data
          return that
  delete: ->
    that = @
    @_table
      .where(id: @id)
      .delete()
      .then ->
        delete that.id
  load: ->
    that = @
    @_table
      .where(id: @id)
      .first()
      .then (data) ->
        _.assign that, data

################################################################################
# movie

Movie = (data) ->
  Record.call this, data

Movie.prototype = Object.create Record.prototype

_.assign Movie.prototype,
  name: ->

################################################################################
# person

Person = (data) ->
  Record.call this, data

Person.prototype = Object.create Record.prototype

_.assign Person.prototype,
  name: ->

################################################################################
# export factory

module.exports = (mesa) ->
  result = {}

  result.Movie = (data) -> Movie.call this, data
  result.Movie.prototype = Object.create Movie.prototype

  mesaForActiveRecord = mesa
    .queueBeforeEach(camelToSnakeObject)
    .queueAfterEach(snakeToCamelObject)

  movieTable = mesaForActiveRecord
    .table('movie')
    .allow('name')
    .queueAfterEach (data) ->
      new result.Movie data

  personTable = mesaForActiveRecord
    .table('person')
    .allow('name')
    .queueAfterEach (data) ->
      new result.Person data

  result.Person = (data) -> Person.call this, data
  result.Person.prototype = Object.create Person.prototype

  # make all instances share the same table property
  result.Movie.prototype._table = movieTable
  result.Person.prototype._table = personTable

  # static methods

  _.assign result.Movie,
    getWhereName: (name) ->
      movieTable.where(name: name).first()

    getWhereNameMatches: (name) ->
      movieTable.where(name: name).first()

    getWhereId: (id) ->
      movieTable.where(id: id).first()

    all: ->
      movieTable.find()

    starring: (nameOrId) ->
      Person.getWhereName(actorName) ->

  return result
