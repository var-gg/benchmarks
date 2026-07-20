import { fetchUser } from "./mod-a";

// FLOATING across files: fetchUser returns Promise (type known only via import)
fetchUser(1);
