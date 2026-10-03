-- Plays 2D UI/game-feel sounds by name (see Config/AudioConfig). Rarity drives intensity:
-- common pieces are a light tick, Legendary+ get bigger cues, Secret is dramatic.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared.Config.AudioConfig)
local RarityConfig = require(Shared.Config.RarityConfig)

local AudioController = {}

local folder: Folder
local rng = Random.new()
local lastPlayed: { [string]: number } = {}

function AudioController:Init()
	folder = Instance.new("Folder")
	folder.Name = "GrowARampSounds"
	folder.Parent = SoundService
end

function AudioController:Play(name: string, volumeScale: number?)
	local def = AudioConfig.Sounds[name]
	if not def then
		return
	end
	-- Avoid stacking the same sound many times in one frame.
	local now = os.clock()
	if (lastPlayed[name] or 0) > now - 0.03 then
		return
	end
	lastPlayed[name] = now
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume * (volumeScale or 1)
	local pitch = def.Pitch or 1
	if def.PitchVariance then
		pitch += rng:NextNumber(-def.PitchVariance, def.PitchVariance)
	end
	sound.PlaybackSpeed = pitch
	sound.Parent = folder
	sound:Play()
	Debris:AddItem(sound, 6)
end

function AudioController:PlayPiece(rarity: string, mutation: string?)
	local info = RarityConfig.Rarities[rarity]
	local tier = if info then info.Tier else 1
	if tier >= 7 then
		self:Play("PieceSecret")
	elseif tier >= 5 then
		self:Play("PieceLegendary")
	elseif tier >= 3 then
		self:Play("PieceRare")
	else
		self:Play("PieceCommon")
	end
	if mutation then
		task.delay(0.15, function()
			self:Play("Mutation")
		end)
	end
end

return AudioController
