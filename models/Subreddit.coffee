export default class Subreddit

	constructor: (data) -> @[k] = v for k, v of {

		id: data.id
		name: data.display_name.toLowerCase()
		isNSFW: data.over18 or data.over_18
		isPrivate: data.subreddit_type is 'private'
		isRestricted: data.subreddit_type is 'restricted'
		isPremiumOnly: data.subreddit_type is 'gold_restricted'
		isArchived: data.subreddit_type is 'archived'
		isQuarantined: data.quarantine
		defaultCommentSort: data.suggested_comment_sort

		createDate: new Date(1000 * data.created_utc)

		displayName: data.display_name
		tagline: data.title
		blurb: data.public_description
		
		color1: data.primary_color or ''
		color2: data.key_color or ''
		iconUrl: data.community_icon or data.icon_img or ''
		bannerUrl: data.banner_background_image or data.mobile_banner_img or data.banner_img or ''

		numberOfUsersBrowsing: data.accounts_active
		numberOfSubscribers: data.subscribers

	}