#include <cstring>
#include <string>

#include <unity.h>

#include "todo/auth.h"
#include "../helpers/hex.h"

using todo::AddMemberResult;
using todo::MemberRegistry;

void setUp() {}
void tearDown() {}

void test_hmac_sha256_rfc4231_case_2() {
  const char* key = "Jefe";
  const char* msg = "what do ya want for nothing?";
  auto d = todo::hmacSha256((const uint8_t*)key, strlen(key), (const uint8_t*)msg, strlen(msg));
  TEST_ASSERT_EQUAL_STRING("5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843",
                           toHex(d).c_str());
}

void test_hmac_sha256_rfc4231_case_6_key_longer_than_block() {
  uint8_t key[131];
  memset(key, 0xaa, sizeof key);
  const char* msg = "Test Using Larger Than Block-Size Key - Hash Key First";
  auto d = todo::hmacSha256(key, sizeof key, (const uint8_t*)msg, strlen(msg));
  TEST_ASSERT_EQUAL_STRING("60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54",
                           toHex(d).c_str());
}

void test_auth_mac_matches_shared_vector() {
  todo::Nonce n{};
  for (size_t i = 0; i < n.size(); i++) n[i] = (uint8_t)(0xa0 + i);
  TEST_ASSERT_EQUAL_STRING("fac4725981f6273e72f559d39aaaf01973375f67fe07269384b8c32f2241fd4a",
                           toHex(todo::authMac(vectorSecret(), n, "anna")).c_str());
  TEST_ASSERT_EQUAL_STRING("4ad03de7d04e042582a05dd151c36af6a5688c3af407c279a64c1464b58a1e88",
                           toHex(todo::authMac(vectorSecret(), n, "żaneta")).c_str());
}

static todo::Member member(const std::string& id, const std::string& name) {
  todo::Member m;
  m.userId = id;
  m.displayName = name;
  return m;
}

void test_registry_adds_and_updates_name_of_returning_member() {
  MemberRegistry r;
  TEST_ASSERT_EQUAL_INT((int)AddMemberResult::Added, (int)r.add(member("anna", "Anna")));
  TEST_ASSERT_EQUAL_INT((int)AddMemberResult::Replaced, (int)r.add(member("anna", "Ania")));
  TEST_ASSERT_EQUAL_UINT(1, r.size());
  TEST_ASSERT_NOT_NULL(r.find("anna"));
  TEST_ASSERT_EQUAL_STRING("Ania", r.find("anna")->displayName.c_str());
  TEST_ASSERT_NULL(r.find("bartek"));
}

void test_full_registry_evicts_least_recently_seen_member() {
  MemberRegistry r;
  for (size_t i = 0; i < todo::kMaxMembers; i++)
    TEST_ASSERT_EQUAL_INT((int)AddMemberResult::Added, (int)r.add(member("u" + std::to_string(i), "U")));
  // u0 przedstawia się ponownie, więc najdawniej widziany jest teraz u1.
  TEST_ASSERT_EQUAL_INT((int)AddMemberResult::Replaced, (int)r.add(member("u0", "U0")));
  TEST_ASSERT_EQUAL_INT((int)AddMemberResult::Evicted, (int)r.add(member("extra", "X")));
  TEST_ASSERT_EQUAL_UINT(todo::kMaxMembers, r.size());
  TEST_ASSERT_NULL(r.find("u1"));
  TEST_ASSERT_NOT_NULL(r.find("u0"));
  TEST_ASSERT_NOT_NULL(r.find("extra"));
  TEST_ASSERT_EQUAL_INT((int)AddMemberResult::Evicted, (int)r.add(member("extra2", "Y")));
  TEST_ASSERT_NULL(r.find("u2"));
}

void test_registry_persistence_keeps_names_and_recency_order() {
  MemberRegistry src;
  for (size_t i = 0; i < todo::kMaxMembers - 1; i++) src.add(member("u" + std::to_string(i), "U"));
  src.add(member("żaneta", "Żaneta"));
  src.add(member("u0", "U0"));  // u0 na koniec kolejki
  auto bytes = src.serialize();

  MemberRegistry dst;
  TEST_ASSERT_TRUE(MemberRegistry::deserialize(bytes, dst));
  TEST_ASSERT_EQUAL_UINT(todo::kMaxMembers, dst.size());
  TEST_ASSERT_EQUAL_STRING("Żaneta", dst.find("żaneta")->displayName.c_str());
  TEST_ASSERT_EQUAL_INT((int)AddMemberResult::Evicted, (int)dst.add(member("nowy", "N")));
  TEST_ASSERT_NULL(dst.find("u1"));
  TEST_ASSERT_NOT_NULL(dst.find("u0"));

  bytes[bytes.size() / 2] ^= 0x5A;
  MemberRegistry bad;
  TEST_ASSERT_FALSE(MemberRegistry::deserialize(bytes, bad));
  TEST_ASSERT_EQUAL_UINT(0, bad.size());
}

int main() {
  UNITY_BEGIN();
  RUN_TEST(test_hmac_sha256_rfc4231_case_2);
  RUN_TEST(test_hmac_sha256_rfc4231_case_6_key_longer_than_block);
  RUN_TEST(test_auth_mac_matches_shared_vector);
  RUN_TEST(test_registry_adds_and_updates_name_of_returning_member);
  RUN_TEST(test_full_registry_evicts_least_recently_seen_member);
  RUN_TEST(test_registry_persistence_keeps_names_and_recency_order);
  return UNITY_END();
}
