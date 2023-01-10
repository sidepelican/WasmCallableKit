import { TagRecord } from "./common.gen.js";

export type Vec2 = {
    x: number;
    y: number;
} & TagRecord<"Vec2">;
