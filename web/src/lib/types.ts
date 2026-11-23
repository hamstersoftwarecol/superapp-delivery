export type UserRole = "customer" | "restaurant" | "courier" | "admin";

export type AccountStatus = "pending" | "approved" | "suspended";

export type User = {
  id: number;
  name: string;
  email: string;
  phone: string | null;
  role: UserRole;
  status: AccountStatus;
  status_note: string | null;
  created_at: string;
  restaurants?: Restaurant[];
};

export type MenuItem = {
  id: number;
  restaurant_id: number;
  name: string;
  description: string | null;
  price_cents: number;
  is_available: boolean;
};

export type Restaurant = {
  id: number;
  name: string;
  description: string | null;
  address: string;
  latitude: string | null;
  longitude: string | null;
  delivery_fee_cents: number;
  is_open: boolean;
  menu_items?: MenuItem[];
};

export type OrderStatus =
  | "pending"
  | "accepted"
  | "preparing"
  | "ready"
  | "picked_up"
  | "delivered"
  | "rejected"
  | "cancelled";

export type OrderItem = {
  id: number;
  menu_item_id: number | null;
  name: string;
  unit_price_cents: number;
  quantity: number;
};

export type Order = {
  id: number;
  status: OrderStatus;
  subtotal_cents: number;
  delivery_fee_cents: number;
  total_cents: number;
  delivery_address: string;
  notes: string | null;
  payment_method: string;
  created_at: string;
  restaurant?: Restaurant;
  customer?: User;
  courier?: User | null;
  items?: OrderItem[];
};

export type Resource<T> = { data: T };
export type Collection<T> = { data: T[] };
