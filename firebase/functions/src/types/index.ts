/**
 * Convivio Type Definitions
 *
 * Shared TypeScript interfaces for Firebase Functions.
 * Mirror the iOS Swift models for consistency.
 */

import { Timestamp } from 'firebase-admin/firestore';

// ============================================================
// ENUMS
// ============================================================

export type WineType = 'red' | 'white' | 'rosé' | 'sparkling' | 'dessert' | 'fortified';
export type BottleStatus = 'available' | 'reserved' | 'consumed' | 'gifted';
export type UserRole = 'owner' | 'family' | 'guest';
export type MovementType = 'in' | 'out' | 'move';
export type FoodieLevel = 'casual' | 'enthusiast' | 'expert';
export type PreferenceType = 'allergy' | 'intolerance' | 'diet' | 'dislike' | 'preference';
export type DinnerStyle = 'informal' | 'convivial' | 'elegant';
export type CookingTime = 'quick' | 'oneHour' | 'twoHours' | 'unlimited';
export type BudgetLevel = 'economic' | 'standard' | 'premium' | 'luxury';
export type DinnerStatus = 'planning' | 'confirmed' | 'completed' | 'cancelled';
export type CourseType = 'aperitif' | 'starter' | 'first' | 'main' | 'side' | 'dessert' | 'pairing';

// ============================================================
// USER & AUTH
// ============================================================

export interface User {
  id: string;
  email?: string;
  displayName?: string;
  photoUrl?: string;
  preferences?: UserPreferences;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface UserPreferences {
  language: string;
  notifications: boolean;
  defaultCellarId?: string;
}

// ============================================================
// CELLAR & LOCATIONS
// ============================================================

export interface Cellar {
  id: string;
  name: string;
  description?: string;
  members: Record<string, UserRole>;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface Location {
  id: string;
  cellarId: string;
  name: string;
  path: LocationPath;
  capacity?: number;
  currentCount: number;
  createdAt: Timestamp;
}

export interface LocationPath {
  shelf?: string;
  row?: number;
  slot?: number;
}

// ============================================================
// WINE & BOTTLES
// ============================================================

export interface Wine {
  id: string;
  name: string;
  producer?: string;
  vintage?: number;
  type: WineType;
  region?: string;
  country?: string;
  appellation?: string;
  grapes?: string[];
  alcohol?: number;
  description?: string;
  imageUrl?: string;
  createdBy: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface Bottle {
  id: string;
  wineId: string;
  cellarId: string;
  locationId?: string;
  status: BottleStatus;
  acquiredAt?: Timestamp;
  acquiredPrice?: number;
  acquiredFrom?: string;
  consumedAt?: Timestamp;
  notes?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface Movement {
  id: string;
  bottleId: string;
  type: MovementType;
  fromLocationId?: string;
  toLocationId?: string;
  reason?: string;
  createdBy: string;
  createdAt: Timestamp;
}

// ============================================================
// RATINGS & TASTE PROFILES
// ============================================================

export interface Rating {
  id: string;
  wineId: string;
  userId: string;
  rating: number;
  isFavorite: boolean;
  notes?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface TasteProfile {
  id: string;
  wineId: string;
  userId: string;
  acidity: number;
  tannin: number;
  body: number;
  sweetness: number;
  effervescence: number;
  aromas: string[];
  flavors: string[];
  finish: string;
  createdAt: Timestamp;
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
  updatedAt: Timestamp;
}

export interface FoodPreference {
  id: string;
  friendId: string;
  type: PreferenceType;
  category: string;
  severity?: string;
  notes?: string;
  createdAt: Timestamp;
}

// ============================================================
// DINNER EVENTS
// ============================================================

export interface DinnerEvent {
  id: string;
  name: string;
  date: Timestamp;
  time?: string;
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
  status: 'invited' | 'confirmed' | 'declined';
  createdAt: Timestamp;
}

// ============================================================
// MENU PROPOSALS
// ============================================================

export interface WinePairing {
  name: string;
  reasoning: string;
  details?: string;
}

export interface MenuCourse {
  course: CourseType;
  name: string;
  description: string;
  dietaryFlags: string[];
  prepTime: number;
  notes?: string;
  cellarWine?: WinePairing;
  marketWine?: WinePairing;
}

export interface MenuProposal {
  courses: MenuCourse[];
  reasoning: string;
  wineStrategy?: string;
  seasonContext: string;
  guestConsiderations: string[];
  totalPrepTime: number;
  generatedAt: Timestamp;
}

export interface WineProposal {
  id: string;
  dinnerId?: string;
  type: 'available' | 'suggested_purchase';
  wineId?: string;
  suggestedWineName?: string;
  suggestedWineDetails?: string;
  course: CourseType;
  reasoning: string;
  isSelected: boolean;
  createdAt: Timestamp;
}

// ============================================================
// CONVERSATIONS & CHAT
// ============================================================

export interface Conversation {
  id: string;
  userId: string;
  title?: string;
  lastMessageAt: Timestamp;
  createdAt: Timestamp;
}

export interface ChatMessage {
  id: string;
  conversationId: string;
  role: 'user' | 'assistant';
  content: string;
  toolCalls?: ToolCall[];
  toolResults?: ToolResult[];
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
// EXTRACTION & OCR
// ============================================================

export interface ExtractionResult {
  ocrText: string;
  extractedFields: {
    name?: { value: string; confidence: number };
    producer?: { value: string; confidence: number };
    vintage?: { value: string; confidence: number };
    type?: { value: string; confidence: number };
    region?: { value: string; confidence: number };
    country?: { value: string; confidence: number };
    grapes?: { value: string[]; confidence: number };
    alcohol?: { value: number; confidence: number };
  };
  overallConfidence: number;
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
}

export interface ChatResponse {
  success: boolean;
  response?: string;
  conversationId?: string;
  wineReferences?: Wine[];
  error?: string;
}
