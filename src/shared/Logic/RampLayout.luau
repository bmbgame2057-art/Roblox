--!strict
-- Places modular track pieces for one lane and validates every placement.
--
-- Growth direction: every lane has a fixed launch lip on the shared launch line. The ramp grows
-- *backward and upward* from the lip toward the hub: piece 1 feeds the lip, piece N is the top
-- where the ride starts. Adding a piece never moves existing pieces, and the launch point never
-- moves, so landmark distances stay honest for every lane.
--
-- Placement of a new piece:
--   1. The previous top's entry socket is the anchor where the new piece's EXIT must sit.
--   2. newEntryCFrame = anchor * exitSocket:Inverse()
--   3. Validate: lane boundaries, height band, heading limit, no overlap with other pieces.
--   4. Accept -> its entry socket becomes the new anchor.
--
-- Pure logic (CFrame/Vector3 only); used identically by the server and the client.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local TrackDefinitions = require(Shared.Definitions.TrackDefinitions)
local TrackGeometry = require(Shared.Logic.TrackGeometry)
local PieceCodec = require(Shared.Logic.PieceCodec)

type TrackDefinition = TrackDefinitions.TrackDefinition
type Geometry = TrackGeometry.Geometry
type PieceEntry = PieceCodec.PieceEntry

export type Placement = {
	Index: number,
	Entry: PieceEntry,
	Def: TrackDefinition,
	Geom: Geometry,
	CFrame: CFrame, -- world entry socket
	Positions: { Vector3 }, -- world sample positions
}

export type Candidate = {
	Def: TrackDefinition,
	Mirror: boolean,
	Steer: number,
	Geom: Geometry,
	CFrame: CFrame,
	Positions: { Vector3 },
}

type GridEntry = {
	Piece: number,
	Position: Vector3,
	DEntry: number,
}

local LANES = GameConfig.Lanes
local TRACK = GameConfig.Track
local PLOTS = GameConfig.Plots

local CELL = 16
local TAN_HALF = math.tan(math.rad(LANES.AngleStepDeg / 2))
local LATERAL_MARGIN = TRACK.HalfWidthForBounds + LANES.LaneGap
local LIP_ENTRY_RADIUS = LANES.LipExitRadius - LANES.LipLength
local MAX_RADIUS = LIP_ENTRY_RADIUS + 0.5
local COS_MAX_HEADING = math.cos(math.rad(TRACK.MaxHeadingDeg))
local OH2 = TRACK.OverlapHorizontal * TRACK.OverlapHorizontal

local RampLayout = {}
RampLayout.__index = RampLayout

export type RampLayout = typeof(setmetatable(
	{} :: {
		LaneIndex: number,
		LaneFrame: CFrame,
		LipEntry: CFrame,
		LipGeom: Geometry,
		Anchor: CFrame,
		Placements: { Placement },
		_grid: { [number]: { GridEntry } },
	},
	RampLayout
))

---------------------------------------------------------------------------------------------------
-- Lane helpers (static)

function RampLayout.GetLaneAngle(laneIndex: number): number
	return ((LANES.Count + 1) / 2 - laneIndex) * LANES.AngleStepDeg
end

function RampLayout.GetLaneFrame(laneIndex: number): CFrame
	return CFrame.new(LANES.Focus) * CFrame.Angles(0, math.rad(RampLayout.GetLaneAngle(laneIndex)), 0)
end

-- Lane-local point (x right, y up, r = distance from the focus along the lane) to a world CFrame
-- that faces along the lane.
function RampLayout.LanePoint(laneIndex: number, x: number, y: number, r: number): CFrame
	return RampLayout.GetLaneFrame(laneIndex) * CFrame.new(x, y, -r)
end

function RampLayout.GetLipEntry(laneIndex: number): CFrame
	return RampLayout.LanePoint(laneIndex, 0, LANES.LipBaseY, LIP_ENTRY_RADIUS)
end

function RampLayout.GetLipExit(laneIndex: number): CFrame
	return RampLayout.GetLipEntry(laneIndex) * TrackGeometry.GetLip().Exit
end

function RampLayout.GetPadCFrame(laneIndex: number): CFrame
	return RampLayout.LanePoint(laneIndex, 0, 0, LANES.BoardRadius)
end

function RampLayout.GetCartCFrame(laneIndex: number): CFrame
	return RampLayout.LanePoint(laneIndex, 0, PLOTS.PadTopY, LANES.BoardRadius + PLOTS.CartForwardOffset)
end

function RampLayout.GetReturnCFrame(laneIndex: number): CFrame
	return RampLayout.LanePoint(laneIndex, 0, PLOTS.PadTopY + 3, LANES.BoardRadius - PLOTS.ReturnBackOffset)
end

-- Lateral half-width available to track centre lines at a given radius.
function RampLayout.LateralLimit(radius: number): number
	return radius * TAN_HALF - LATERAL_MARGIN
end

---------------------------------------------------------------------------------------------------
-- Construction

local function cellCoord(value: number): number
	return math.floor(value / CELL)
end

local function cellKey(cx: number, cz: number): number
	return cx * 65536 + cz
end

function RampLayout.new(laneIndex: number): RampLayout
	local self = setmetatable({
		LaneIndex = laneIndex,
		LaneFrame = RampLayout.GetLaneFrame(laneIndex),
		LipEntry = RampLayout.GetLipEntry(laneIndex),
		LipGeom = TrackGeometry.GetLip(),
		Anchor = CFrame.new(),
		Placements = {},
		_grid = {},
	}, RampLayout)
	self.Anchor = self.LipEntry
	-- The lip is registered as piece 0 so nothing may overlap it.
	local positions = {}
	for i, sample in self.LipGeom.Samples do
		positions[i] = self.LipEntry * sample.Position
	end
	self:_register(0, self.LipGeom, positions)
	return self
end

function RampLayout._register(self: RampLayout, pieceIndex: number, geom: Geometry, positions: { Vector3 })
	for i, position in positions do
		local key = cellKey(cellCoord(position.X), cellCoord(position.Z))
		local bucket = self._grid[key]
		if not bucket then
			bucket = {}
			self._grid[key] = bucket
		end
		table.insert(bucket, { Piece = pieceIndex, Position = position, DEntry = geom.Dist[i] })
	end
end

---------------------------------------------------------------------------------------------------
-- Validation

function RampLayout.InBounds(self: RampLayout, position: Vector3): (boolean, string?)
	if position.Y < TRACK.MinY then
		return false, "below"
	end
	if position.Y > TRACK.MaxY then
		return false, "above"
	end
	local localPoint = self.LaneFrame:PointToObjectSpace(position)
	local radius = -localPoint.Z
	if radius < LANES.TrackMinRadius then
		return false, "hub"
	end
	if radius > MAX_RADIUS then
		return false, "lip"
	end
	if math.abs(localPoint.X) > RampLayout.LateralLimit(radius) then
		return false, "lane"
	end
	return true, nil
end

-- Returns true if any registered sample (other than the joint area of `skipPiece`) is too close.
function RampLayout.Collides(self: RampLayout, position: Vector3, skipPiece: number): boolean
	local cx, cz = cellCoord(position.X), cellCoord(position.Z)
	local skip = TRACK.JunctionSkip
	local overlapVertical = TRACK.OverlapVertical
	for dx = -1, 1 do
		for dz = -1, 1 do
			local bucket = self._grid[cellKey(cx + dx, cz + dz)]
			if bucket then
				for _, other in bucket do
					if not (other.Piece == skipPiece and other.DEntry < skip) then
						local delta = other.Position - position
						if math.abs(delta.Y) < overlapVertical and delta.X * delta.X + delta.Z * delta.Z < OH2 then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

-- Where a piece's entry socket would land if placed on top of the ramp (no validation).
function RampLayout.Project(
	self: RampLayout,
	def: TrackDefinition,
	mirror: boolean?,
	steer: number?
): (CFrame, Geometry)
	local geom = TrackGeometry.Get(def, mirror, steer)
	return self.Anchor * geom.Exit:Inverse(), geom
end

-- Evaluates placing `def` (optionally mirrored / steered) on top of the current ramp.
function RampLayout.Evaluate(
	self: RampLayout,
	def: TrackDefinition,
	mirror: boolean?,
	steer: number?
): (boolean, Candidate | string)
	if #self.Placements >= TRACK.MaxPieces then
		return false, "full"
	end
	local isMirrored = mirror == true and def.Mirror
	local steerSign = if steer and TrackGeometry.CanSteer(def)
		then math.clamp(math.round(steer), -TRACK.SteerLevels, TRACK.SteerLevels)
		else 0
	local entryCFrame, geom = self:Project(def, isMirrored, steerSign)

	-- Heading: the ride direction at the new top must still point down the lane.
	local look = entryCFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 or flat.Unit:Dot(self.LaneFrame.LookVector) < COS_MAX_HEADING then
		return false, "heading"
	end

	local skipPiece = #self.Placements
	local skip = TRACK.JunctionSkip
	local positions = table.create(#geom.Samples)
	for i, sample in geom.Samples do
		local position = entryCFrame * sample.Position
		local ok, reason = self:InBounds(position)
		if not ok then
			return false, reason :: string
		end
		if geom.Length - geom.Dist[i] >= skip and self:Collides(position, skipPiece) then
			return false, "overlap"
		end
		positions[i] = position
	end

	return true,
		{
			Def = def,
			Mirror = isMirrored,
			Steer = steerSign,
			Geom = geom,
			CFrame = entryCFrame,
			Positions = positions,
		}
end

-- Canonical saved entry for a candidate (mirror/steer normalised to what was actually placed).
function RampLayout.MakeEntry(candidate: Candidate, mutation: string?, value: number?): PieceEntry
	return {
		Id = candidate.Def.Id,
		Mutation = mutation,
		Mirror = if candidate.Mirror then true else nil,
		Value = value,
		Steer = if candidate.Steer ~= 0 then candidate.Steer else nil,
	}
end

function RampLayout.Push(self: RampLayout, candidate: Candidate, entry: PieceEntry): Placement
	local index = #self.Placements + 1
	local placement: Placement = {
		Index = index,
		Entry = entry,
		Def = candidate.Def,
		Geom = candidate.Geom,
		CFrame = candidate.CFrame,
		Positions = candidate.Positions,
	}
	self.Placements[index] = placement
	self:_register(index, candidate.Geom, candidate.Positions)
	self.Anchor = candidate.CFrame
	return placement
end

function RampLayout.TryPush(self: RampLayout, entry: PieceEntry): (boolean, Placement?)
	local def = TrackDefinitions.ById[entry.Id]
	if not def then
		return false, nil
	end
	local ok, result = self:Evaluate(def, entry.Mirror, entry.Steer)
	if not ok then
		return false, nil
	end
	local candidate = result :: Candidate
	return true, self:Push(candidate, RampLayout.MakeEntry(candidate, entry.Mutation, entry.Value))
end

-- Rebuilds from saved entries. Invalid pieces (removed content, changed geometry rules) are
-- dropped so a ramp always reconstructs into a valid state. Returns the accepted entries.
function RampLayout.Build(self: RampLayout, entries: { PieceEntry }): ({ PieceEntry }, number)
	local accepted = {}
	local dropped = 0
	for _, entry in entries do
		local ok, placement = self:TryPush(entry)
		if ok and placement then
			table.insert(accepted, placement.Entry)
		else
			dropped += 1
		end
	end
	return accepted, dropped
end

-- Independent copy (placements are immutable records, so only the containers are copied).
function RampLayout.Clone(self: RampLayout): RampLayout
	local copy = setmetatable({
		LaneIndex = self.LaneIndex,
		LaneFrame = self.LaneFrame,
		LipEntry = self.LipEntry,
		LipGeom = self.LipGeom,
		Anchor = self.Anchor,
		Placements = table.clone(self.Placements),
		_grid = {},
	}, RampLayout)
	for key, bucket in self._grid do
		copy._grid[key] = table.clone(bucket)
	end
	return copy
end

-- Builds a brand new layout and requires every entry to fit (used to validate replacements).
function RampLayout.TryBuildStrict(laneIndex: number, entries: { PieceEntry }, count: number?): RampLayout?
	local layout = RampLayout.new(laneIndex)
	for i = 1, count or #entries do
		local ok = layout:TryPush(entries[i])
		if not ok then
			return nil
		end
	end
	return layout
end

---------------------------------------------------------------------------------------------------
-- Queries

-- Lane-local description of a socket: lateral offset (x, + = right), radius from the focus, and
-- heading of the ride direction relative to the lane (radians, + = pointing left / -X).
function RampLayout.Describe(self: RampLayout, socket: CFrame): (number, number, number)
	local localPosition = self.LaneFrame:PointToObjectSpace(socket.Position)
	local localLook = self.LaneFrame:VectorToObjectSpace(socket.LookVector)
	return localPosition.X, -localPosition.Z, math.atan2(-localLook.X, -localLook.Z)
end

function RampLayout.GetCount(self: RampLayout): number
	return #self.Placements
end

function RampLayout.IsAtCap(self: RampLayout): boolean
	return #self.Placements >= TRACK.MaxPieces
end

function RampLayout.GetTopSocket(self: RampLayout): CFrame
	return self.Anchor
end

function RampLayout.GetEntries(self: RampLayout): { PieceEntry }
	local entries = table.create(#self.Placements)
	for i, placement in self.Placements do
		entries[i] = placement.Entry
	end
	return entries
end

function RampLayout.GetTotalLength(self: RampLayout): number
	local total = 0
	for _, placement in self.Placements do
		total += placement.Geom.Length
	end
	return total
end

-- Highest track surface below `position` (for support pillars). Returns ground height (0) if none.
function RampLayout.FloorBelow(self: RampLayout, position: Vector3, excludePiece: number?): number
	local best = 0
	local cx, cz = cellCoord(position.X), cellCoord(position.Z)
	for dx = -1, 1 do
		for dz = -1, 1 do
			local bucket = self._grid[cellKey(cx + dx, cz + dz)]
			if bucket then
				for _, other in bucket do
					if other.Piece ~= excludePiece then
						local delta = other.Position - position
						if delta.Y < -3 and delta.X * delta.X + delta.Z * delta.Z < 36 then
							best = math.max(best, other.Position.Y)
						end
					end
				end
			end
		end
	end
	return best
end

return RampLayout
