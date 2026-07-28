import { describe, expect, test } from "bun:test"
import { normalize } from "../src/normalize"

describe("normalize", () => {
  test("sorts keys and removes volatile values", () => {
    expect(normalize({ updated_at: "now", z: 1, a: 2 })).toEqual({ a: 2, z: 1 })
  })

  test("removes wildcard array paths", () => {
    expect(normalize({ data: [{ id: 1, value: "a" }] }, ["data.*.id"])).toEqual({
      data: [{ value: "a" }]
    })
  })
})
