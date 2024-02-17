export const toServerSideType = (columnType: string) => {
  switch (columnType) {
    case 'home':
    case 'notifications':
    case 'public':
    case 'thread':
    case 'account':
    case 'explore':
      return columnType;
    default:
      if (columnType.includes('list:') || columnType.includes('antenna:')) {
        return 'home';
      } else {
        return 'public'; // community, account, hashtag
      }
  }
};
