/**************************************************************************/
/*                                                                        */
/*  SPDX-License-Identifier: LGPL-2.1                                     */
/*  Copyright (C) 2026 Frama-C Linux contributors                         */
/*                                                                        */
/**************************************************************************/

/*
 * Bounded environment for the Open vSwitch flow-set callback.  The mapped
 * compilation database places the selected source directory first, allowing
 * the same harness to analyze either the checked-out file or a historical
 * source override without changing Linux itself.
 */
#include <datapath.c>

struct frama_c_ovs_message {
  struct genlmsghdr genl;
  struct ovs_header ovs;
};

void ovs_match_init(struct sw_flow_match *match,
                    struct sw_flow_key *key, bool reset_key,
                    struct sw_flow_mask *mask)
{
  (void)match;
  (void)key;
  (void)reset_key;
  (void)mask;
}

int ovs_nla_get_match(struct net *net, struct sw_flow_match *match,
                      const struct nlattr *key, const struct nlattr *mask,
                      bool log)
{
  (void)net;
  (void)match;
  (void)key;
  (void)mask;
  (void)log;
  return 0;
}

bool ovs_nla_get_ufid(struct sw_flow_id *sfid, const struct nlattr *attr,
                      bool log)
{
  (void)sfid;
  (void)attr;
  (void)log;
  return false;
}

u32 ovs_nla_get_ufid_flags(const struct nlattr *attr)
{
  (void)attr;
  return 0;
}

struct net_device *dev_get_by_index_rcu(struct net *net, int ifindex)
{
  static struct net_device device;
  (void)net;
  (void)ifindex;
  return &device;
}

struct vport *ovs_internal_dev_get_vport(struct net_device *device)
{
  static struct datapath datapath;
  static struct vport vport;
  (void)device;
  vport.dp = &datapath;
  return &vport;
}

struct sw_flow *ovs_flow_tbl_lookup_exact(struct flow_table *table,
                                          const struct sw_flow_match *match)
{
  static struct sw_flow flow;
  (void)table;
  (void)match;
  return &flow;
}

struct sw_flow *ovs_flow_tbl_lookup_ufid(struct flow_table *table,
                                         const struct sw_flow_id *sfid)
{
  static struct sw_flow flow;
  (void)table;
  (void)sfid;
  return &flow;
}

int frama_c_ovs_flow_cmd_set_harness(void)
{
  struct sk_buff skb = { 0 };
  struct sock sk = { 0 };
  struct net net = { 0 };
  struct genl_info info = { 0 };
  struct frama_c_ovs_message message = { 0 };
  struct nlmsghdr nlh = { 0 };
  struct nlattr key = {
    .nla_len = sizeof(key),
    .nla_type = OVS_FLOW_ATTR_KEY,
  };
  struct nlattr *attrs[__OVS_FLOW_ATTR_MAX] = { 0 };

  sock_net_set(&sk, &net);
  skb.sk = &sk;
  attrs[OVS_FLOW_ATTR_KEY] = &key;
  info.family = &dp_flow_genl_family;
  info.nlhdr = &nlh;
  info.genlhdr = &message.genl;
  info.attrs = attrs;

  return ovs_flow_cmd_set(&skb, &info);
}
