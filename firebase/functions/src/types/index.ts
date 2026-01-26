/**
 * Sommelier App - Shared Types
 * 
 * Questo file definisce il data model completo dell'applicazione.
 * Usato sia dalle Cloud Functions che dai client (iOS/Web).
 */

import { Timestamp } from 'firebase-admin/firestore';

// ============================================================
// ENUMS
// ============================================================

export type WineType = 'red' | 'white' | 'rosé' | 'sparkling' | 'dessert' | 'fortified';

export type BottleStatus = 'available' | 'consumed' | 'gifted' | 'broken';

export type MovementType = 'in' | 'out' | 'move';

export type UserRole = 'owner' | 'family';

export type FoodieLevel = 'simple' | 'curious' | 'demanding';

export type DinnerStyle = 'informal' | 'convivial' | 'elegant';

export type CookingTime = '30min' | '1h' | '2h' | '3h+';

export type BudgetLevel = 'economy' | 'standard' | 'premium';

export type DinnerStatus = 'planning' | 'confirmed' | 'completed' | 'cancelled';

export type FoodPrefType = 'allergy' | 'intolerance' | 'dislike' | 'preference' | 'diet';

export type FoodPrefSeverity = 'mild' | 'moderate' | 'severe';

export type PhotoType = 'label_front' | 'label_back' | 'bottle' | 'other';

export type CourseType = 'aperitif' | 'starter' | 'first' | 'main' | 'dessert' | 'pairing';

export type ProposalType = 'available' | 'suggested_purchase';

// ============================================================
// CORE ENTITIES
// ============================================================

export interface User {
  id: string;
  email: string;
  displayName: string;
  photoUrl?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface UserPreferences {
  favoriteTypes?: WineType[];
  avoidTypes?: WineType[];
  favoriteRegions?: string[];
  notes?: string;
}

// ============================================================
// CELLAR & LOCATION
// ============================================================

export interface Cellar {
  id: string;
  name: string;
  description?: string;
  members: Record<string, UserRole>; // userId -> role
  createdAt: Timestamp;
  createdBy: string;
}

export interface Location {
  id: string;
  cellarId: string;
  shelf: string;        // es. "A", "B", "Scaffale 1"
  row?: number;         // riga nel ripiano
  slot?: number;        // posizione nella riga
  description?: string;
  capacity?: number;    // bottiglie max
}

// Full path for display
export interface LocationPath {
  cellarName: string;
  shelf: string;
  row?: number;
  slot?: number;
}

// ============================================================
// WINE & BOTTLE
// ============================================================

export interface Wine {
  id: string;
  name: string;
  producer?: string;
  vintage?: number;
  type: WineType;
  region?: string;
  country?: string;
  grapes?: string[];
  alcoholContent?: number;
  description?: string;
  createdAt: Timestamp;
  createdBy: string;
}

export interface Bottle {
  id: string;
  wineId: string;
  locationId: string;
  status: BottleStatus;
  acquiredAt?: Timestamp;
  acquiredPrice?: number;
  consumedAt?: Timestamp;
  notes?: string;
  createdAt: Timestamp;
  createdBy: string;
}

// Bottle with denormalized wine data for display
export interface BottleWithWine extends Bottle {
  wine: Wine;
  location?: Location;
}

export interface Movement {
  id: string;
  bottleId: string;
  type: MovementType;
  fromLocationId?: string;
  toLocationId?: string;
  reason?: string;
  performedBy: string;
  performedAt: Timestamp;
}

// ============================================================
// RATINGS & TASTE
// ============================================================

export interface Rating {
  id: string;
  wineId: string;
  rating: number;       // 1-5
  isFavorite: boolean;
  notes?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface TasteProfile {
  id: string;
  wineId: string;
  acidity: number;      // 1-5
  tannin: number;       // 1-5
  body: number;         // 1-5
  sweetness: number;    // 1-5
  effervescence: number; // 0-5
  notes?: string;
  tags?: string[];
  createdAt: Timestamp;
}

// Aggregated wine data for a user
export interface UserWineData {
  wineId: string;
  rating?: Rating;
  tasteProfile?: TasteProfile;
  consumptionCount: number;
  lastConsumedAt?: Timestamp;
}

// ============================================================
// FRIENDS & PREFERENCES
// ============================================================

export interface Friend {
  id: string;
  name: string;
  email?: string;
  phone?: string;
  foodieLevel: FoodieLevel;
  notes?: string;
  createdAt: Timestamp;
}

export interface FoodPreference {
  id: string;
  friendId: string;
  type: FoodPrefType;
  category: string;     // es. "dairy", "gluten", "meat"
  description?: string;
  severity?: FoodPrefSeverity;
}

// Friend with all preferences loaded
export interface FriendWithPreferences extends Friend {
  preferences: FoodPreference[];
}

// ============================================================
// DINNER EVENTS
// ============================================================

export interface DinnerEvent {
  id: string;
  name: string;
  date: Timestamp;
  time?: string;        // "20:30"
  style: DinnerStyle;
  cookingTime: CookingTime;
  budgetLevel: BudgetLevel;
  notes?: string;
  status: DinnerStatus;
  menuProposal?: MenuProposal;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface DinnerGuest {
  id: string;
  dinnerId: string;
  friendId: string;
  confirmed: boolean;
}

export interface WineProposal {
  id: string;
  dinnerId: string;
  type: ProposalType;
  wineId?: string;              // if available
  suggestedWineName?: string;   // if suggested_purchase
  suggestedWineDetails?: string;
  course: CourseType;
  reasoning: string;
  isSelected: boolean;
  createdAt: Timestamp;
}

// ============================================================
// AI-GENERATED CONTENT
// ============================================================

export interface WinePairing {
  name: string;
  reasoning: string;
  details?: string;  // For market wines: type, region, producer
}

export interface MenuCourse {
  course: CourseType;
  name: string;
  description: string;
  dietaryFlags: string[];   // "GF", "Vegan", "LF", etc.
  prepTime: number;         // minutes
  notes?: string;
  cellarWine?: WinePairing;   // Wine from user's cellar
  marketWine?: WinePairing;   // Wine to purchase
}

export interface MenuProposal {
  courses: MenuCourse[];
  reasoning: string;
  wineStrategy?: string;      // Strategy for wine pairings
  seasonContext: string;
  guestConsiderations: string[];
  totalPrepTime: number;
  generatedAt: Timestamp;
}

// ============================================================
// PHOTOS & OCR
// ============================================================

export interface PhotoAsset {
  id: string;
  storageUrl: string;
  thumbnailUrl?: string;
  type: PhotoType;
  bottleId?: string;
  wineId?: string;
  createdAt: Timestamp;
}

export interface ExtractedField {
  value: string;
  confidence: number;     // 0-1
}

export interface ExtractionResult {
  id: string;
  photoAssetId: string;
  rawOcrText: string;
  extractedFields: {
    name?: ExtractedField;
    producer?: ExtractedField;
    vintage?: ExtractedField;
    region?: ExtractedField;
    country?: ExtractedField;
    alcoholContent?: ExtractedField;
    grapes?: ExtractedField;
  };
  overallConfidence: number;
  wasManuallyEdited: boolean;
  finalWineId?: string;
  createdAt: Timestamp;
}

// ============================================================
// CHAT & CONVERSATIONS
// ============================================================

export interface Conversation {
  id: string;
  title?: string;
  context?: {
    cellarId?: string;
    dinnerId?: string;
  };
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  toolCalls?: ToolCall[];
  toolResults?: ToolResult[];
  wineReferences?: string[];  // wineIds mentioned
  createdAt: Timestamp;
}

export interface ToolCall {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
}

export interface ToolResult {
  toolCallId: string;
  result: unknown;
}

// ============================================================
// API REQUEST/RESPONSE TYPES
// ============================================================

export interface ExtractWineRequest {
  photoUrl: string;
  userId: string;
}

export interface ExtractWineResponse {
  success: boolean;
  extraction?: ExtractionResult;
  suggestedMatches?: Wine[];
  error?: string;
}

export interface ProposeDinnerRequest {
  dinnerId: string;
  userId: string;
}

export interface ProposeDinnerResponse {
  success: boolean;
  menu?: MenuProposal;
  wineProposals?: {
    available: WineProposal[];
    suggested: WineProposal[];
  };
  error?: string;
}

export interface ChatRequest {
  message: string;
  conversationId?: string;
  userId: string;
  context?: {
    cellarId?: string;
    dinnerId?: string;
  };
}

export interface ChatResponse {
  success: boolean;
  response?: string;
  conversationId?: string;
  wineReferences?: Wine[];
  suggestedActions?: SuggestedAction[];
  error?: string;
}

export interface SuggestedAction {
  type: 'select_wine' | 'consume_wine' | 'add_to_dinner' | 'view_details';
  label: string;
  wineId?: string;
  data?: Record<string, unknown>;
}

// ============================================================
// INVENTORY AGGREGATIONS
// ============================================================

export interface CellarStats {
  totalBottles: number;
  byType: Record<WineType, number>;
  byStatus: Record<BottleStatus, number>;
  vintageRange: { min: number; max: number };
  avgRating?: number;
  lastUpdated: Timestamp;
}

export interface WineInventory {
  wineId: string;
  wine: Wine;
  totalBottles: number;
  availableBottles: number;
  locations: LocationPath[];
  avgRating?: number;
  lastConsumed?: Timestamp;
}

// ============================================================
// SEARCH & FILTER
// ============================================================

export interface WineSearchFilters {
  type?: WineType[];
  region?: string[];
  vintageMin?: number;
  vintageMax?: number;
  ratingMin?: number;
  available?: boolean;
  query?: string;       // free text search
}

export interface WineSearchResult {
  wines: WineInventory[];
  totalCount: number;
  filters: WineSearchFilters;
}

// ============================================================
// SERVICE INSTRUCTIONS (AI-generated)
// ============================================================

export interface WineServiceInstructions {
  wineId: string;
  idealTemperature: number;     // Celsius
  currentTemperature?: number;  // if in cellar
  coolingTimeMinutes?: number;
  decantationMinutes?: number;
  glassType: string;
  openingTime?: string;         // "19:30"
  notes: string[];
}
