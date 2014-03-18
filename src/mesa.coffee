mohair = require 'mohair'
Promise = require 'bluebird'
_ = require 'underscore'

module.exports =

###################################################################################
# fluent

    clone: ->
        Object.create this

    # prototypically inherit from this
    # and set key to value

    fluent: (key, value) ->
        object = this.clone()
        object[key] = value
        object

    # call: (f, args...) ->
    #     f.apply this, args

###################################################################################
# setters

    $mohair: mohair.escape((string) -> "\"#{string}\"")
    $returning: '*'
    $primaryKey: 'id'
    $allowedColumns: []
    $returnFirst: false

    returning: (arg) ->
        this.fluent '$returning', arg
    connection: (arg) ->
        this.fluent '$connection', arg
    allowedColumns: (columns) ->
        this.fluent '$allowedColumns', this.$allowedColumns.concat(columns)
    primaryKey: (arg) ->
        this.fluent '$primaryKey', arg
    table: (arg) ->
        this.fluent('$table', arg)
            .fluent '$mohair', this.$mohair.table arg
    returnFirst: (arg = true) ->
        this.fluent '$returnFirst', arg
    debug: (arg) ->
        this.fluent '$debug', arg

###################################################################################
# pipelining

    $beforeInsert: []
    $afterInsert: []
    $beforeUpdate: []
    $afterUpdate: []
    $afterSelect: []
    $afterDelete: []

    beforeInsert: (args...) ->
        this.fluent '$beforeInsert', this.$beforeInsert.concat(args)
    afterInsert: (args...) ->
        this.fluent '$afterInsert', this.$afterInsert.concat(args)
    beforeUpdate: (args...) ->
        this.fluent '$beforeUpdate', this.$beforeUpdate.concat(args)
    afterUpdate: (args...) ->
        this.fluent '$afterUpdate', this.$afterUpdate.concat(args)
    # run on the records returned by a delete
    afterDelete: (args...) ->
        this.fluent '$afterUpdate', this.$afterUpdate.concat(args)
    afterSelect: (args...) ->
        this.fluent '$afterSelect', this.$afterSelect.concat(args)

    runPipeline: (pipeline, data) ->
        reducer = (soFar, f) ->
            soFar.then f
        pipeline.reduce reducer, q(data)

###################################################################################
# pass through to mohair

    sql: ->
        this.replacePlaceholders this.$mohair.sql()
    params: ->
        this.$mohair.params()

    raw: (args...) ->
        this.$mohair.raw args...

    where: (args...) ->
        this.fluent '$mohair', this.$mohair.where args...
    join: (args...) ->
        this.fluent '$mohair', this.$mohair.join args...

    select: (args...) ->
        this.fluent '$mohair', this.$mohair.select args...
    limit: (arg) ->
        this.fluent '$mohair', this.$mohair.limit arg
    offset: (arg) ->
        this.fluent '$mohair', this.$mohair.offset arg
    order: (arg) ->
        this.fluent '$mohair', this.$mohair.order arg
    group: (arg) ->
        this.fluent '$mohair', this.$mohair.group arg
    with: (arg) ->
        this.fluent '$mohair', this.$mohair.with arg

###################################################################################
# connection

    getConnection: (cb) ->
        self = this

        unless self.$connection?
            throw new Error "the method you are calling requires a call to connection() before it"
        if 'function' is typeof self.$connection
            self.$connection cb
            return
        setTimeout ->
            cb null, self.$connection

    query: (sql, params) ->
        self = this

        self.$debug('MESA', 'QUERY', sql, params)?

        d = q.defer()
        self.getConnection (err, connection, done) ->
            if err?
                done?()
                d.reject err
                return
            connection.query sql, params, (err, results) ->
                done?()
                if err?
                    d.reject err
                    return
                d.resolve results

        d.promise

###################################################################################
# command

    insert: (dataOrArray) ->
        self = this

        array = if Array.isArray dataOrArray then dataOrArray else [dataOrArray]
        self.returnFirst().insertMany array

    insertMany: (array) ->
        self = this

        beforeInsert = (data) ->
            self.runPipeline self.$beforeInsert, data

        q.all(array.map beforeInsert).then (processedArray) ->
            cleanArray = processedArray.map (data) ->
                self.pickAllowedColumns data

            cleanArray.forEach (cleanData) ->
                if Object.keys(cleanData).length is 0
                    return q.reject new Error 'nothing to insert'

            query = self.$mohair.insertMany cleanArray
            sql = self.appendReturning self.replacePlaceholders query.sql()

            self.query(sql, query.params()).then (results) ->
                self.afterQuery self.$afterInsert, results

    update: (data) ->
        self = this

        self.runPipeline(self.$beforeUpdate, data).then (processedData) ->
            cleanData = self.pickAllowedColumns processedData

            if Object.keys(cleanData).length is 0
                return q.reject new Error 'nothing to update'

            query = self.$mohair.update cleanData
            sql = self.appendReturning self.replacePlaceholders query.sql()

            self.query(sql, query.params()).then (results) ->
                self.afterQuery self.$afterUpdate, results

    delete: ->
        self = this

        query = self.$mohair.delete()
        sql = self.appendReturning self.replacePlaceholders query.sql()

        self.query(sql, query.params()).then (results) ->
            self.afterQuery self.$afterDelete, results

###################################################################################
# query

    find: ->
        self = this

        self.query(self.sql(), self.params()).then (results) ->
            self.afterQuery self.$afterSelect, results

    exists: ->
        self = this

        self.query(self.sql(), self.params()).then (results) ->
            results.rows? and results.rows.length isnt 0

###################################################################################
# easy sugar

    first: ->
        this.limit(1)
            .returnFirst()
            .find()

###################################################################################
# util

    replacePlaceholders: (sql) ->
        # replace ?, ?, ... with $1, $2, ...
        index = 1
        sql.replace /\?/g, -> '$' + index++

    pickAllowedColumns: (data) ->
        self = this

        _.pick data, self.$allowedColumns

    afterQuery: (pipeline, results) ->
        self = this

        if results.rows?
            processRow = (row) ->
                self.runPipeline pipeline, row
            q.all(results.rows.map processRow).then (processedRows) ->
                if self.$returnFirst
                    processedRows[0]
                else
                    processedRows
        else
            results

    appendReturning: (sql) ->
        self = this

        if self.$returning?
            sql + ' RETURNING ' + self.$returning
        else
            sql
