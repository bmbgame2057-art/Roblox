--!strict
-- Sound hooks. The placeholder ids are sounds bundled with the Roblox client (rbxasset://) so the
-- game is never silent; replace them with final uploaded audio (rbxassetid://...) when ready.

export type SoundDefinition = {
	Id: string,
	Volume: number,
	Pitch: number?,
	PitchVariance: number?,
}

local AudioConfig = {}

AudioConfig.Sounds = {
	PieceCommon = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25, Pitch = 1.2, PitchVariance = 0.08 },
	PieceRare = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 0.9 },
	PieceLegendary = { Id = "rbxasset://sounds/victory.wav", Volume = 0.45, Pitch = 1.15 },
	PieceSecret = { Id = "rbxasset://sounds/victory.wav", Volume = 0.7, Pitch = 0.8 },
	Mutation = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1.6 },
	EnterCart = { Id = "rbxasset://sounds/snap.wav", Volume = 0.5 },
	Lift = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.35, Pitch = 0.7 },
	RideStart = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5 },
	SpeedTick = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.12, Pitch = 1.6, PitchVariance = 0.1 },
	Boost = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.45, Pitch = 1.3 },
	Launch = { Id = "rbxasset://sounds/Rocket shot.wav", Volume = 0.55 },
	Air = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.25, Pitch = 0.8 },
	Landing = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.35, Pitch = 0.7 },
	NewRecord = { Id = "rbxasset://sounds/victory.wav", Volume = 0.55 },
	Purchase = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, Pitch = 1.4 },
	Error = { Id = "rbxasset://sounds/button.wav", Volume = 0.4, Pitch = 0.7 },
	UIClick = { Id = "rbxasset://sounds/button.wav", Volume = 0.3 },
	Offline = { Id = "rbxasset://sounds/victory.wav", Volume = 0.4, Pitch = 1.3 },
	Event = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 0.7 },
} :: { [string]: SoundDefinition }

return AudioConfig
