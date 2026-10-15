class CompanyOverview {
  const CompanyOverview({
    required this.id,
    required this.name,
    required this.status,
    this.logoUrl,
    this.industry,
    this.address,
    this.website,
  });
  final String id, name, status;
  final String? logoUrl, industry, address, website;
}
