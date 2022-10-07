import ID from '../../../core/ID.coffee'

export default (rawData) ->
	result =
		main: null
		sub: []
	for user_fullname, user of rawData
		result.sub.push({
			id: ID('user', user.name)
			data: user
			partial: true
		})
	result.main =
		id: null
		data: result.sub.map((dataset) -> ID.var(dataset.id, 1))
	return result