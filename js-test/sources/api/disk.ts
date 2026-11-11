// POS: top-level api/ folder, untyped req (fast-filesystem shape)
export default async function handler(req: any, res: any) {
  const { path } = req.body;
  const q = req.query.p;
  res.json({ path, q });
}
