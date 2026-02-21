from rest_framework.pagination import PageNumberPagination


class FlexiblePagination(PageNumberPagination):
    """
    Pagination class that allows the client to set ?page_size=N.
    Default is 25, max is 5000.
    """
    page_size = 25
    page_size_query_param = 'page_size'
    max_page_size = 5000
