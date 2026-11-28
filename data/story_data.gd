extends RefCounted
## All story text: the first-launch intro, radio transmissions and the two endings.
## Radio messages play once, when their trigger fires (see GameManager).

const INTRO_PAGES: Array[String] = [
	"The sky went quiet first.\n\nBirds stopped. Satellites went dark one by one, and for eleven minutes nobody on Earth could say why.",
	"Then they came down. Not machines, not animals. Both. Flesh grown around metal, metal threaded through flesh.\n\nThe old armies met them and lost within a week.",
	"What saved us was the lighthouse.\n\nBuilt on the cliff before anyone remembered why, it holds the Core: the one power source that turns the planet's grid, its engines, its tides of light.",
	"The aliens did not come for our land, our cities or our people. They came for the Core. It is their food. Everything else is in the way.",
	"You are the newest recruit of the agency that holds the lighthouse. Ten colonies stand with us, run by their own people. They trade with you, and they need you.\n\nKeep the light on.",
]

const RADIO := {
	"mothership_down": {
		"title": "Command: the Mothership is down",
		"text": "Its hull is breaking up over the field. The swarm has lost its anchor. Whatever comes next, you made it possible.",
	},
	"mission_1": {
		"title": "Command: well done, Recruit",
		"text": "Command to lighthouse. First sortie logged. The scouts you met are the cheapest thing the swarm owns. They do not think. Others will.",
	},
	"mission_3": {
		"title": "Command: they are learning",
		"text": "Soldiers are in the field now. They hold range, they shoot, they pull back when hurt. Do not chase a retreating soldier into open ground.",
	},
	"mission_6": {
		"title": "Colony relay: thank you",
		"text": "This is the colony relay net. Every colony is watching your missions. Fewer colonies fall when you win. Remember that when the base is under attack and the reward looks good.",
	},
	"mission_10": {
		"title": "Command: the Core is singing",
		"text": "Engineers report the Core hums louder each month. That sound reaches further than we thought. The aliens can hear it from beyond the Moon.",
	},
	"rank_1": {
		"title": "Command: promoted to Cadet",
		"text": "You have earned your first stripe. Better weapons and another comrade slot are open to you.",
	},
	"rank_2": {
		"title": "Command: promoted to Operative",
		"text": "Operative. You no longer follow the plan, you write it. The interceptor jet is now yours to command.",
	},
	"rank_3": {
		"title": "Command: promoted to Sentinel",
		"text": "Sentinel. Be careful: the swarm raises its own officers when we raise ours. Expect cunning from the soldiers now. They flank, and they fall back to fight again.",
	},
	"rank_4": {
		"title": "Command: promoted to Warden",
		"text": "Warden. The plasma cannon is cleared for you. The colonies call your name when they pray for the lights.",
	},
	"rank_5": {
		"title": "Command: promoted to Commander",
		"text": "Commander. We found the first record of the Core in the cliff itself. Someone built the lighthouse to feed it, not to guard it. We do not yet know who.",
	},
	"rank_6": {
		"title": "Command: Keeper of the Light",
		"text": "Keeper. Every colony stands because of you. There is one transmission left that only a Keeper may answer. Open the final transmission when you are ready.",
	},
}

const FINAL_PAGES: Array[String] = [
	"FINAL TRANSMISSION\n\nKeeper, we have decoded the signal behind the swarm. It is not an invasion. It is a harvest, and it has been repeating for ten thousand years.",
	"The Core is a seed. It was planted here to ripen, and the swarm returns when it is ready. Every time, someone lights a lighthouse to protect it. Every time, it feeds them in the end.",
	"You hold the switch.\n\nSever the Core and the swarm starves. The grid dies with it, and the colonies will have to learn the dark again.\n\nKeep the light and the Core stays. The grid stays. So does the harvest, and the next Keeper after you.",
]

const ENDINGS := {
	"sever": [
		"You pull the lever.\n\nThe Core goes dark for the first time in ten thousand years. Across the planet the lights fail, the engines stop, the tides of light go still.",
		"In orbit, the swarm falters. Without the scent of the Core they have nothing to follow. Within a month they are gone.\n\nThe colonies light fires and learn the dark. It is slow. It is hard. It is theirs.",
		"ENDING: THE DARK DAWN\n\nThe lighthouse stands empty on its cliff, a monument and a warning. The Keeper walks down to the first town and asks for work.",
	],
	"keep": [
		"You step back from the lever.\n\nThe Core steadies. The lights hold. The colonies cheer, and the sound reaches the lighthouse on the wind.",
		"You know what that means. The harvest is not ended, only delayed. You will train a Keeper after you, and they will train another.\n\nThe light will burn for ten thousand more years, and so will the war.",
		"ENDING: THE ETERNAL WATCH\n\nThe lighthouse never goes dark. Neither does the fight. Somewhere in the sky, patient, the swarm begins to turn back toward home.",
	],
}
